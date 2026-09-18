"""Generate JSON schemas for the PCX extraction and document-routing tasks."""
from pathlib import Path
from pydantic import BaseModel
from cumulus_library_pcx.tools import filetool, llm_schema_json

MODELS_PACKAGE = "cumulus_library_pcx.llm.models"


def annotation_model(task: str) -> type[BaseModel] | None:
    """The Annotation model a task module defines, or None for a helper module (base, lab_base, ...)."""
    return llm_schema_json.annotation_model(task, MODELS_PACKAGE)


def list_tasks() -> list[str]:
    """Task names: every module under llm/models that defines an Annotation model."""
    return llm_schema_json.list_tasks(MODELS_PACKAGE)


def create(annotation, filename: str, output_dir: Path | None = None) -> Path:
    """Write a Pydantic annotation schema, creating the destination directory."""
    directory = Path(output_dir) if output_dir is not None else filetool.path_llm("schemas")
    return llm_schema_json.save_schema(annotation, directory / filename)


def create_pcx_llm_study_variables(output_dir: Path | None = None) -> list[Path]:
    """Generate one schema per PCX task, including document routing."""
    paths = list()
    for task in list_tasks():
        paths.append(create(
            annotation_model(task),
            f"pcx-{task.replace('_', '-')}-annotation.json",
            output_dir,
        ))
    return paths


if __name__ == "__main__":
    for path in create_pcx_llm_study_variables():
        print(path)
