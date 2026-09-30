"""Schema tooling works with non-PCX models and preserves PCX exports."""
import csv
import json
from enum import StrEnum

import pytest
from pydantic import BaseModel, Field

from cumulus_library_pcx.tools import llm_schema_json, llm_schema_csv, llm_schema_txt
from cumulus_library_pcx.stage import llm_schema


class ReviewStatus(StrEnum):
    """YES: accepted by default. NO: rejected by default."""
    YES = 'YES'
    NO = 'NO'


class ReviewMention(BaseModel):
    status: ReviewStatus = Field(description='Choose one. YES: explicitly accepted.')
    spans: list[str] = Field(default_factory=list, description='Quoted evidence.')


class ReviewGroup(BaseModel):
    mentions: list[ReviewMention] | None = Field(default=None, description='Review findings.')


class ReviewAnnotation(BaseModel):
    group: ReviewGroup = Field(description='Review group.')


def test_discovery_uses_supplied_package(tmp_path, monkeypatch):
    package = tmp_path / 'schema_tool_example'
    package.mkdir()
    (package / '__init__.py').write_text('')
    (package / 'task.py').write_text(
        'from pydantic import BaseModel\n'
        'class ExampleAnnotation(BaseModel):\n    value: str\n')
    (package / 'helper.py').write_text('from .task import ExampleAnnotation\n')
    (package / '_private.py').write_text('raise RuntimeError("Do not import private modules")\n')
    monkeypatch.syspath_prepend(str(tmp_path))
    assert llm_schema_json.list_tasks('schema_tool_example') == ['task']
    assert llm_schema_json.annotation_model('helper', 'schema_tool_example') is None
    assert llm_schema_json.annotation_model('task', 'schema_tool_example').__name__ == 'ExampleAnnotation'
    (package / 'ambiguous.py').write_text(
        'from pydantic import BaseModel\n'
        'class FirstAnnotation(BaseModel):\n    pass\n'
        'class SecondAnnotation(BaseModel):\n    pass\n')
    with pytest.raises(ValueError, match='more than one Annotation'):
        llm_schema_json.annotation_model('ambiguous', 'schema_tool_example')


def test_summary_preserves_nested_descriptions_and_enum_fallback(tmp_path):
    path = llm_schema_csv.save_summary(
        ReviewAnnotation, tmp_path / 'review' / 'example.csv', exclude_fields={'spans'})
    with path.open(newline='') as source:
        rows = list(csv.DictReader(source))
    status_rows = [row for row in rows if row['mention_key']]
    assert [(row['annot_col'], row['mention_key'], row['mention_value']) for row in status_rows] == [
        ('group.mentions', 'YES', 'explicitly accepted.'),
        ('group.mentions', 'NO', 'rejected by default.'),
    ]
    assert any(row['mention_value'] == 'Review findings.' for row in rows)
    assert not any(row['mention_col'] == 'spans' for row in rows)
    assert any(row[3] == 'spans' for row in llm_schema_csv.summarize(ReviewAnnotation))


def test_schema_export_accepts_explicit_output_path(tmp_path):
    path = llm_schema_json.save_schema(ReviewAnnotation, tmp_path / 'schemas' / 'example.json')
    schema = json.loads(path.read_text())
    assert schema['title'] == 'ReviewAnnotation'
    assert schema['properties']['group']['description'] == 'Review group.'
    assert schema['$defs']['ReviewStatus']['enum'] == ['YES', 'NO']


def test_pcx_adapters_generate_matching_task_sets(tmp_path):
    tasks = llm_schema.list_tasks()
    schemas = llm_schema.make_schemas(tmp_path / 'schemas')
    summaries = llm_schema.make_summaries(tmp_path / 'summaries')
    assert {p.name for p in schemas} == {f'pcx-{task.replace("_", "-")}-annotation.json' for task in tasks}
    assert {p.name for p in summaries} == {f'pcx__{task}.{suffix}' for task in tasks for suffix in ('csv', 'txt')}
    for path in summaries:
        if path.suffix == '.txt':
            assert path.read_text().startswith('model = "')
            continue
        with path.open(newline='') as source:
            rows = list(csv.DictReader(source))
        assert rows
        assert not any(row['mention_col'] in {'spans', 'has_mention'} for row in rows)


class ScoredMention(BaseModel):
    has_mention: bool = Field(default=False)
    spans: list[str] = Field(default_factory=list)
    score: int | None = Field(default=None, ge=0, le=3, description='Documented score.')
    statuses: list[ReviewStatus] = Field(default_factory=list)


class Node(BaseModel):
    children: list['Node'] = Field(default_factory=list)


def test_txt_summary_types_bounds_enums_and_excluded_fields(tmp_path):
    class ScoredAnnotation(BaseModel):
        status: ReviewStatus = Field(description='Choose one.')
        scored: list[ScoredMention] = Field(default_factory=list)

    text = llm_schema_txt.summarize(ScoredAnnotation, exclude_fields={'has_mention', 'spans'})
    lines = text.splitlines()
    assert lines[0] == 'model = "ScoredAnnotation"'
    assert 'status = ReviewStatus (Choice Value)' in lines
    assert '    # Choose one.' in lines
    assert '    #   - YES' in lines
    assert 'scored: A (possibly empty) list of ScoredMention instances, which contain:' in lines
    assert '    score = Optional mention of [Integer number between 0 and 3 (inclusive)]' in lines
    assert '    statuses = A list of [ReviewStatus (Choice Value)]' in lines
    assert '        #   - NO' in lines          # enum values are listed for list[Enum] too
    assert 'spans' not in text and 'has_mention' not in text

    path = llm_schema_txt.save_summary(ScoredAnnotation, tmp_path / 'txt' / 'example.txt',
                                       exclude_fields={'has_mention', 'spans'})
    assert path.read_text() == text


def test_txt_summary_bounds_phrases():
    from annotated_types import Ge, Gt, Le, Lt
    assert llm_schema_txt.bounds_to_string([Ge(0), Le(3)]) == 'between 0 and 3 (inclusive)'
    assert llm_schema_txt.bounds_to_string([Gt(0), Lt(1)]) == 'between 0 and 1 (exclusive)'
    assert llm_schema_txt.bounds_to_string([Ge(0)]) == '0 or greater'
    assert llm_schema_txt.bounds_to_string([Gt(0), Le(10)]) == 'greater than 0 and 10 or less'
    assert llm_schema_txt.bounds_to_string([]) == ''


def test_txt_summary_stops_on_recursive_model():
    text = llm_schema_txt.summarize(Node)
    assert '# Node (recursive, described above)' in text


def test_txt_summary_renders_every_pcx_task():
    for task in llm_schema.list_tasks():
        text = llm_schema_txt.summarize(llm_schema.annotation_model(task),
                                        exclude_fields={'has_mention', 'spans'})
        assert text.startswith('model = "') and len(text.splitlines()) > 2, task


def test_stage_prepares_files_and_runtime_builder_refreshes_them(tmp_path, monkeypatch):
    import tomllib
    from cumulus_library_pcx.tools import filetool

    monkeypatch.setattr(filetool, 'path_llm', lambda name: tmp_path / 'llm' / name)
    monkeypatch.setattr(filetool, 'path_project', lambda name: tmp_path / name)
    manifest = tomllib.loads(llm_schema.make().read_text())
    assert manifest['actions'][0]['files'] == ['stage/llm_schema.py']
    assert manifest['actions'][0]['type'] == 'build:serial'
    schemas = list((tmp_path / 'llm/schemas').glob('*.json'))
    assert len(schemas) == len(llm_schema.list_tasks())
    assert len(list((tmp_path / 'llm/summaries').iterdir())) == 2 * len(schemas)
    schemas[0].unlink()
    builder = llm_schema.LlmSchemaBuilder()
    builder.prepare_queries(config=None, manifest=None)
    assert schemas[0].exists()
    assert builder.queries == []


def test_schema_stage_precedes_the_nlp_workflow():
    from cumulus_library_pcx.stage.manifest import STAGES

    names = [stage.name for stage in STAGES]
    assert names.index('llm_schema') < names.index('nlp_all_50k')
