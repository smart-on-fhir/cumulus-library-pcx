"""
NLP wide tables: <prefix>__llm_<projection> from the raw <prefix>__nlp_<task>_<deployment> tables,
where <prefix> is the study prefix from manifest.toml (tablespace.PREFIX).

Each sql/template/llm_<projection>.sql.jinja is rendered once against the selected
deployments (UNION ALL of <prefix>__nlp_<task>_<deployment>) at the task version declared in a
`.workflow` file, and written to sql/generated/. A workflow's tasks select which templates
belong to it: projection `<task>` or `<task>_<suffix>`.

The generated queries require the selected deployments' NLP source tables.
"""
import re
from pathlib import Path
from typing import Iterable
from cumulus_library_pcx.tools import settings
from cumulus_library_pcx.tools import filetool, toml_tool, template
from cumulus_library_pcx.tools.tablespace import PREFIX
from cumulus_library_pcx.tools.actions import Action, SqlParallelAction

DEFAULT_DEPLOYMENTS = settings.NLP_DEPLOYMENTS
DEPLOYMENT_SUFFIX = re.compile(r'^[a-z0-9_]+$')   # becomes part of an Athena table name
TEMPLATE_GLOB = 'llm_*.sql.jinja'      # sql/template/llm_<projection>.sql.jinja

#-----------------------------------------------------------------------------
# Prepare (Test / inspection)
#-----------------------------------------------------------------------------
def make_resources(workflow: str, label: str, toml_file: str,
                   deployments: Iterable[str] = DEFAULT_DEPLOYMENTS,
                   output_dir: Path | None = None) -> list[Path]:
    """
    Render into `output_dir` (mirroring the project layout) instead of the project.
    With no output_dir this is the stage's make() plus the SQL paths.
    :return: SQL paths, then the stage TOML
    """
    if output_dir is None:
        return make_wide(workflow, deployments) + [toml_tool.save_actions_toml(make_actions(workflow, label, deployments), toml_file)]
    output_dir = Path(output_dir)
    paths = list()
    for file_sql, sql in render(workflow, deployments).items():
        path = output_dir / filetool.path_sql_generated(file_sql).relative_to(filetool.path_project())
        path.parent.mkdir(parents=True, exist_ok=True)
        paths.append(filetool.write_text(sql, path))
    action = SqlParallelAction([filetool.path_sql_generated(p.name) for p in paths], label)
    return paths + [toml_tool.save_actions_toml(action, output_dir / toml_file)]

#-----------------------------------------------------------------------------
# Templates
#-----------------------------------------------------------------------------
def dict_template_task(tasks: dict[str, int]) -> dict[Path, str]:
    """
    :return: sql/template/llm_*.sql.jinja -> task, for the templates these tasks own
    """
    out = dict()
    for path in sorted(filetool.path_sql_template().glob(TEMPLATE_GLOB)):
        task = task_of(path, tasks)
        if task:
            out[path] = task
    return out

#-----------------------------------------------------------------------------
# NLP Tasks
#-----------------------------------------------------------------------------
def dict_task_versions(workflow: str) -> dict[str, int]:
    """
    :param workflow: filename like 'nlp_clinical_tasks.workflow'
    :return: NLP task -> task version
    """
    out = dict()
    for task, config in toml_tool.load_toml(workflow)['tables'].items():
        version = config.get('version')
        if type(version) is not int or version < 1:
            raise ValueError(f"{workflow}: task {task!r} must have a positive integer version")
        out[task] = version
    return out

def task_of(template_path: Path, tasks: dict[str, int]) -> str | None:
    """
    :return: the longest task name that this projection extends (diagnosis_wide -> diagnosis), or None
    """
    name = projection(template_path)
    matching = [task for task in tasks if name == task or name.startswith(task + '_')]
    return max(matching, key=len) if matching else None

#-----------------------------------------------------------------------------
# Deployments
#-----------------------------------------------------------------------------
def list_deployments(deployments: Iterable[str]) -> list[str]:
    """
    :return: sorted, de-duplicated NLP deployment suffixes (<prefix>__nlp_<task>_<deployment>)
    """
    out = sorted(set(deployments))
    bad = [d for d in out if not DEPLOYMENT_SUFFIX.match(d)]
    if not out or bad:
        raise ValueError(f"deployment suffixes must be non-empty [a-z0-9_]+, got {bad or out}")
    return out

def projection(template_path: Path) -> str:
    return template_path.name.removeprefix('llm_').removesuffix('.sql.jinja')

#-----------------------------------------------------------------------------
# make/render
#-----------------------------------------------------------------------------
def make_wide(workflow: str, deployments: Iterable[str] = DEFAULT_DEPLOYMENTS) -> list[Path]:
    """
    :return: sql/generated/<prefix>__llm_*.sql written for the workflow and deployments
    """
    return [filetool.save_sql_generated(file_sql, sql) for file_sql, sql in render(workflow, deployments).items()]

def make_actions(workflow: str, label: str, deployments: Iterable[str] = DEFAULT_DEPLOYMENTS) -> list[Action]:
    return [SqlParallelAction(make_wide(workflow, deployments), label)]

def render(workflow: str, deployments: Iterable[str] = DEFAULT_DEPLOYMENTS) -> dict[str, str]:
    """
    Render every projection of the workflow before anything is written.
    :return: sql/generated filename -> SQL
    """
    deployments = list_deployments(deployments)
    tasks = dict_task_versions(workflow)
    out = dict()
    for template_path, task in dict_template_task(tasks).items():
        sql = template.load(template_path.name,
                                table_names=[f'{PREFIX}__nlp_{task}_{deployment}' for deployment in deployments],
                                task_version=tasks[task])
        out[f'{PREFIX}__{template_path.name.removesuffix(".jinja")}'] = sql.strip() + '\n'
    if not out:
        raise ValueError(f"{workflow}: no sql/template matches its tasks {sorted(tasks)}")
    return out
