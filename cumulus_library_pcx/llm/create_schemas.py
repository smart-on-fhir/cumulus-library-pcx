"""Generate JSON schemas for the PCX extraction and document-routing tasks."""
import importlib
import inspect
import json
from pathlib import Path

from pydantic import BaseModel

from cumulus_library_pcx.tools import filetool

MODELS_PACKAGE = "cumulus_library_pcx.llm.models"


def annotation_model(task: str) -> type[BaseModel] | None:
    """The Annotation model a task module defines, or None for a helper module (base, lab_base, ...)."""
    module = importlib.import_module(f"{MODELS_PACKAGE}.{task}")
    found = list()
    for name, cls in inspect.getmembers(module, inspect.isclass):
        if name.endswith("Annotation") and issubclass(cls, BaseModel) and cls.__module__ == module.__name__:
            found.append(cls)
    if len(found) > 1:
        raise ValueError(f"{module.__name__} defines more than one Annotation model: {found}")
    return found[0] if found else None


def list_tasks() -> list[str]:
    """Task names: every module under llm/models that defines an Annotation model."""
    out = list()
    for py_file in sorted(filetool.path_llm("models").glob("*.py")):
        if not py_file.stem.startswith("_") and annotation_model(py_file.stem):
            out.append(py_file.stem)
    return out


def create(annotation, filename: str, output_dir: Path | None = None) -> Path:
    """Write a Pydantic annotation schema, creating the destination directory."""
    directory = Path(output_dir) if output_dir is not None else filetool.path_llm("schemas")
    directory.mkdir(parents=True, exist_ok=True)
    file_path = directory / filename
    file_path.write_text(json.dumps(annotation.model_json_schema(), indent=2) + "\n", encoding="utf-8")
    return file_path


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
