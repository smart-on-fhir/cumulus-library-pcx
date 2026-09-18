"""NLP wide SQL contract: workflows, schemas, models, templates and the saved SQL agree."""
import json
import os
import re
import subprocess
import sys
import tomllib
import pytest

from cumulus_library_pcx.stage.llm_schema import annotation_model, list_tasks
from cumulus_library_pcx.stage import nlp_clinical_wide, nlp_document_wide
from cumulus_library_pcx.tools import filetool, nlp_wide
from cumulus_library_pcx.tools.tablespace import PREFIX

STAGES = [nlp_clinical_wide, nlp_document_wide]
DOCUMENT_TASKS = {"document_type", "document_topic"}


def workflow_of(task: str) -> str:
    return nlp_document_wide.WORKFLOW if task in DOCUMENT_TASKS else nlp_clinical_wide.WORKFLOW


def model_schema(task: str) -> dict:
    """JSON schema of the task's Pydantic annotation model."""
    return annotation_model(task).model_json_schema()


def model_fields(schema: dict) -> dict:
    """
    JSON Schema -> nested field-presence tree, the shape Cumulus Library gives an NLP result:
    arrays collapse to their item shape, leaves are None, optional fields are kept (the SQL
    still needs their columns when values are null). Unsupported unions fail rather than
    weakening the check.
    """
    definitions = schema.get("$defs", {})

    def walk(node: dict):
        if "$ref" in node:
            prefix = "#/$defs/"
            ref = node["$ref"]
            if not ref.startswith(prefix):
                raise ValueError(f"Unsupported schema reference: {ref}")
            return walk(definitions[ref.removeprefix(prefix)])
        if "anyOf" in node:
            choices = [choice for choice in node["anyOf"] if choice.get("type") != "null"]
            if len(choices) != 1:
                raise ValueError("Expected a single non-null schema alternative")
            return walk(choices[0])
        if node.get("type") == "object":
            return {name: walk(field) for name, field in node["properties"].items()}
        if node.get("type") == "array":
            return walk(node["items"])
        if node.get("type") in {"string", "integer", "number", "boolean", "null"}:
            return None
        raise ValueError(f"Unsupported schema shape: {node}")

    result = walk(schema)
    if not isinstance(result, dict) or not result:
        raise ValueError("An annotation must define a nonempty object schema")
    return result


def templates_of(stage) -> dict[str, str]:
    """rendered sql/generated filename -> task, for one stage"""
    out = dict()
    for template_path, task in nlp_wide.dict_template_task(nlp_wide.dict_task_versions(stage.WORKFLOW)).items():
        out[f'{PREFIX}__{template_path.name.removesuffix(".jinja")}'] = task
    return out


#-----------------------------------------------------------------------------
# workflow <-> schema <-> model
#-----------------------------------------------------------------------------
@pytest.mark.parametrize("task", list_tasks())
def test_configured_schema_matches_the_model(task):
    config = tomllib.loads(filetool.path_project(workflow_of(task)).read_text())["tables"][task]
    assert json.loads(filetool.path_project(config["response_schema"]).read_text()) == model_schema(task)
    assert config["select_by_table"] == f"pcx__llm_document_task_{task}"
    assert task in nlp_wide.dict_task_versions(workflow_of(task))


def test_nested_arrays_and_optional_fields_are_required():
    fields = model_fields(model_schema("systemic_therapy"))
    assert "agent_name" in fields["regimens"]["agents"]
    assert "administration_date_precision" in fields["regimens"]["agents"]["administrations"]
    assert "has_mention" in fields["regimens"]["agents"]
    assert fields["regimens"]["agents"]["spans"] is None
    with pytest.raises(ValueError, match="single non-null"):
        model_fields({"type": "object", "properties": {"x": {"anyOf": [{"type": "string"}, {"type": "number"}]}}})


#-----------------------------------------------------------------------------
# workflow <-> templates
#-----------------------------------------------------------------------------
@pytest.mark.parametrize("stage", STAGES, ids=lambda s: s.WORKFLOW)
def test_every_workflow_task_owns_a_template(stage):
    tasks = nlp_wide.dict_task_versions(stage.WORKFLOW)
    assert set(templates_of(stage).values()) == set(tasks)


def test_every_template_belongs_to_exactly_one_workflow():
    claimed = list()
    for stage in STAGES:
        claimed.extend(templates_of(stage))
    on_disk = sorted(f'{PREFIX}__{p.name.removesuffix(".jinja")}'
                     for p in filetool.path_sql_template().glob(nlp_wide.TEMPLATE_GLOB))
    assert sorted(claimed) == on_disk


#-----------------------------------------------------------------------------
# templates <-> model (every projected result path exists, spans stay behind)
#-----------------------------------------------------------------------------
UNNEST_ALIAS = re.compile(r"UNNEST\(nlp\.result((?:\.\w+)+)\) WITH ORDINALITY AS \w+ \((\w+), \w+\)")


def resolve(contract: dict, path: str, where: str) -> dict | None:
    """Walk a dotted path through the field tree, failing on the first missing part."""
    node = contract
    for part in path.strip(".").split("."):
        assert isinstance(node, dict) and part in node, f"{where}: {path} is not in the model"
        node = node[part]
    return node


@pytest.mark.parametrize("stage", STAGES, ids=lambda s: s.WORKFLOW)
def test_projected_result_paths_exist_in_the_model(stage):
    """Every nlp.result.* path and every <unnest alias>.<field> the SQL reads exists in the model."""
    rendered = nlp_wide.render(stage.WORKFLOW, ["site_a"])
    for file_sql, task in templates_of(stage).items():
        sql = rendered[file_sql]
        contract = model_fields(model_schema(task))
        for path in sorted(set(re.findall(r"nlp\.result((?:\.\w+)+)", sql))):
            resolve(contract, path, f"{file_sql}: nlp.result")
        for list_path, alias in set(UNNEST_ALIAS.findall(sql)):
            item = resolve(contract, list_path, f"{file_sql}: nlp.result")
            # (?<![\w.]) keeps an alias named "result" from matching inside "nlp.result.results"
            for path in sorted(set(re.findall(rf"(?<![\w.]){alias}((?:\.\w+)+)", sql))):
                resolve(item, path, f"{file_sql}: {alias}")
        assert not re.search(r"\.(spans|has_mention)\b", sql), file_sql


@pytest.mark.parametrize("stage", STAGES, ids=lambda s: s.WORKFLOW)
def test_rendered_sql_pins_the_workflow_version_and_unions_deployments(stage):
    tasks = nlp_wide.dict_task_versions(stage.WORKFLOW)
    rendered = nlp_wide.render(stage.WORKFLOW, ["site_b", "site_a", "site_a"])
    for file_sql, task in templates_of(stage).items():
        sql = rendered[file_sql]
        assert sql.count(f"task_version = {tasks[task]}") == 2, file_sql
        assert sql.count("UNION ALL") == 1, file_sql
        assert sql.index(f"pcx__nlp_{task}_site_a") < sql.index(f"pcx__nlp_{task}_site_b"), file_sql


#-----------------------------------------------------------------------------
# settings
#-----------------------------------------------------------------------------
def test_settings_import_without_export_directory():
    env = dict(os.environ)
    env.pop("CUMULUS_LIBRARY_DATA_PATH", None)
    env.pop("ELASTIC_OUTPUT_DIR", None)
    result = subprocess.run([sys.executable, "-c",
        "from cumulus_library_pcx.tools import settings; "
        "assert settings.ELASTIC_OUTPUT_DIR is None"],
        env=env, cwd=filetool.path_project().parent, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
