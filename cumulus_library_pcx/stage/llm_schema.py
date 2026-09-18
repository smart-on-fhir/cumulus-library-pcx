"""Prepare LLM JSON schemas and CSV/TXT summaries before NLP workflows."""
from pathlib import Path

from cumulus_library import BaseTableBuilder
from pydantic import BaseModel

from cumulus_library_pcx.tools import filetool, llm_schema_csv, llm_schema_json, llm_schema_txt
from cumulus_library_pcx.tools.actions import FileAction
from cumulus_library_pcx.tools.toml_tool import save_actions_toml

MODELS_PACKAGE = 'cumulus_library_pcx.llm.models'
SPAN_FIELDS = {'has_mention', 'spans'}


def annotation_model(task: str) -> type[BaseModel] | None:
    return llm_schema_json.annotation_model(task, MODELS_PACKAGE)


def list_tasks() -> list[str]:
    return llm_schema_json.list_tasks(MODELS_PACKAGE)


def make_schemas(output_dir: Path | None = None) -> list[Path]:
    """Save the JSON schemas consumed by the NLP workflows."""
    directory = Path(output_dir) if output_dir is not None else filetool.path_llm('schemas')
    models = [(task, annotation_model(task)) for task in list_tasks()]
    return [llm_schema_json.save_schema(model, directory / f"pcx-{task.replace('_', '-')}-annotation.json")
            for task, model in models]


def make_summaries(output_dir: Path | None = None) -> list[Path]:
    """Save CSV and TXT review summaries, omitting evidence boilerplate."""
    directory = Path(output_dir) if output_dir is not None else filetool.path_llm('summaries')
    models = [(task, annotation_model(task)) for task in list_tasks()]
    return [tool.save_summary(model, directory / f'pcx__{task}.{suffix}', exclude_fields=SPAN_FIELDS)
            for task, model in models
            for suffix, tool in [('csv', llm_schema_csv), ('txt', llm_schema_txt)]]


def make_files() -> list[Path]:
    return make_schemas() + make_summaries()


def make_actions() -> list[FileAction]:
    return [FileAction(['stage/llm_schema.py'], 'Prepare LLM schemas and summaries',
                       build_type='build:serial')]


def make() -> Path:
    make_files()
    return save_actions_toml(make_actions(), 'llm_schema.toml')


class LlmSchemaBuilder(BaseTableBuilder):
    """Refresh schemas when Cumulus executes this stage; no SQL is generated."""

    def prepare_queries(self, config, manifest, *args, **kwargs):
        make_files()


if __name__ == '__main__':
    print(make())
