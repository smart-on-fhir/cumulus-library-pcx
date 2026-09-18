"""Discover Pydantic annotation models and export their JSON schemas.

Callers supply an importable models package and output paths. Study-specific
filenames and defaults belong to callers.
"""
import importlib
import inspect
import json
import pkgutil
from pathlib import Path

import pydantic


def annotation_model(task: str, models_package: str) -> type[pydantic.BaseModel] | None:
    """Return the locally defined *Annotation model, or None for helper modules."""
    module = importlib.import_module(f"{models_package}.{task}")
    found = [cls for name, cls in inspect.getmembers(module, inspect.isclass)
             if name.endswith("Annotation") and issubclass(cls, pydantic.BaseModel)
             and cls.__module__ == module.__name__]
    if len(found) > 1:
        raise ValueError(f"{module.__name__} defines more than one Annotation model: {found}")
    return found[0] if found else None


def list_tasks(models_package: str) -> list[str]:
    """Sorted direct modules in a package that define an annotation model."""
    package = importlib.import_module(models_package)
    return [name for name in sorted(module.name for module in pkgutil.iter_modules(package.__path__)
                                    if not module.ispkg and not module.name.startswith("_"))
            if annotation_model(name, models_package) is not None]


def save_schema(annotation: type[pydantic.BaseModel], file_path: Path | str) -> Path:
    """Write the model's JSON schema, creating the output directory."""
    file_path = Path(file_path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(json.dumps(annotation.model_json_schema(), indent=2) + "\n", encoding="utf-8")
    return file_path


