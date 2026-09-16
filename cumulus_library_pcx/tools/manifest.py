import tomllib
import tomli_w
from pathlib import Path
from functools import lru_cache
from dataclasses import dataclass
from cumulus_library import StudyManifest
from cumulus_library_pcx.tools import filetool

#-----------------------------------------------------------------------------
# get study manifest using cumulus library
#-----------------------------------------------------------------------------
@lru_cache(maxsize=1)
def get_manifest(manifest_path: Path | str = None) -> StudyManifest:
    """
    This method encapsulated changes to v6 StudyManifest
    default: filetool.path_project() = "cumulus_library_pcx"

    :param manifest_path: optional path to manifest file
    :return: StudyManifest
    """
    if not manifest_path:
        manifest_path = filetool.path_project()
    if isinstance(manifest_path, str):
        manifest_path = filetool.path_project(manifest_path)
    return StudyManifest(manifest_path)

#-----------------------------------------------------------------------------
# LOAD ONCE
#-----------------------------------------------------------------------------
MANIFEST = get_manifest()
PREFIX = get_manifest().get_study_prefix()

#-----------------------------------------------------------------------------
# TOML action declarations
#-----------------------------------------------------------------------------
@dataclass(frozen=True)
class Action:
    """
    Cumulus Library basic build action type.

    `manifest.py` owns the TOML details:
    * Action.description becomes the TOML `label` key
      (Cumulus Library deprecated `description` on actions in favor of `label`)
    """
    file_list: list[Path] | list[str]
    description: str = ""

@dataclass(frozen=True)
class FileAction(Action):
    """
    Cumulus Library FILE build action type.
    """
    build_type: str = "build:serial"

@dataclass(frozen=True)
class SqlAction(Action):
    """
    Cumulus Library SQL build action.

    `manifest.py` owns the TOML details:
    * SqlAction.file_list becomes the TOML `files` key
    * each file is written as `athena/<filename>`, or `custom/<filename>`
    * SqlAction.build_type becomes the TOML `type` key
    """
    build_type: str = "build:serial"

@dataclass(frozen=True)
class SqlParallelAction(SqlAction):
    """
    Cumulus Library SQL build action in "parallel".

    `manifest.py` owns the TOML details:
    * SqlAction.file_list becomes the TOML `files` key
    * each file is written as `athena/<filename>`, or `custom/<filename>`
    * SqlAction.build_type becomes the TOML `type` key
    """
    build_type: str = "build:parallel"

@dataclass(frozen=True)
class ExportAction(Action):
    """
    Cumulus Library export action.

    `manifest.py` owns the TOML details:
    * ExportAction.file_list becomes the TOML `tables` key
    * Path entries use their stem; string entries are already table names
    * ExportAction.export_type becomes the TOML `type` key
    """
    export_type: str = "export:counts"

@dataclass(frozen=True)
class UploadAction(Action):
    """
    Cumulus Library file_upload workflow (CSV uploads).

    Unlike the build/export actions above, an upload is a whole submanifest
    (`config_type = "file_upload"`), not one entry in an `[[actions]]` list.

    `manifest.py` owns the TOML details:
    * UploadAction.file_list becomes one `[tables.<table_name>]` block per file
    * table_name is `<prefix><simplename>` when prefix is given
    * otherwise `include_*` files keep their simplename, all others get `valueset_<simplename>`
    * UploadAction.description is NOT written: Cumulus Library rejects unknown keys in file_upload TOML
    """
    prefix: str | None = None

#-----------------------------------------------------------------------------
# TOML builders
#-----------------------------------------------------------------------------
def as_actions_toml(actions: Action| list[ Action | dict]) -> dict:
    """
    Build a Python dict for a mixed list of SQL and export actions.

    This is useful when one manifest contains both build and export actions.
    """
    return {"actions": [_action_to_dict(action) for action in _as_list(actions)]}


def as_upload_toml(action: UploadAction) -> dict:
    """
    Build a Python dict for a file_upload submanifest.

    :param action: upload action (file_list of CSVs, optional table-name prefix)
    :return: dict content for `manifest.toml` submanifest
    """
    tables: dict[str, dict[str, str]] = {}

    for filename in action.file_list:
        filename = Path(filename).name
        table_name = _upload_table_name(filename, action.prefix)
        if table_name in tables:
            raise ValueError(
                f"Duplicate TOML table name {table_name!r}: both "
                f"{tables[table_name]['file']} and {filename} map to it"
            )
        tables[table_name] = {"file": filename}

    return {
        "config_type": "file_upload",
        "tables": tables,
    }

#-----------------------------------------------------------------------------
# TOML read/write helpers
#-----------------------------------------------------------------------------
def load_toml(toml_file: Path | str) -> dict:
    """Read TOML; string filenames are relative to the study package."""
    if not isinstance(toml_file, Path):
        toml_file = filetool.path_project(toml_file)
    with toml_file.open("rb") as source:
        return tomllib.load(source)


def save_actions_toml(actions: Action | list[Action | dict], toml_file: Path | str) -> Path:
    """
    Save an `[[actions]]` manifest; string filenames are relative to the project directory.
    """
    if not isinstance(toml_file, Path):
        toml_file = filetool.path_project(toml_file)
    return _write_toml(as_actions_toml(actions), toml_file)


def save_upload_toml(action: UploadAction, toml_file: Path | str) -> Path:
    """
    Save a file_upload submanifest; string filenames are relative to the spreadsheet directory.
    """
    if not isinstance(toml_file, Path):
        toml_file = filetool.path_spreadsheet(toml_file)
    return _write_toml(as_upload_toml(action), toml_file)


def _write_toml(content: dict, toml_file: Path) -> Path:
    """
    Serialize with tomli-w (no hand-quoted strings or lists) and write to disk.
    """
    return filetool.write_text(tomli_w.dumps(content).strip() + "\n", toml_file)

#-----------------------------------------------------------------------------
# TOML helpers
#-----------------------------------------------------------------------------
def _clean_label(description: str | None = None) -> str:
    """
    Cumulus Library rejects square brackets in an action label (reserved characters).
    """
    if not description:
        return ""
    return description.replace("[", "(").replace("]", ")")

def _sql_file_entry(file: Path | str) -> str:
    """
    TOML `files` entry for one SQL file, relative to the project directory.
    Generated SQL lives in athena/, study-specific hand-written SQL lives in custom/.
    """
    path = Path(file)
    if path.parent.resolve() == filetool.path_custom().resolve():
        return f"custom/{path.name}"
    return f"athena/{path.name}"


def _upload_table_name(filename: str, prefix: str | None = None) -> str:
    """
    TOML `[tables.<name>]` key for one uploaded CSV.
    Default: 'include_*' files keep their simplename, all others get a `valueset_` prefix.
    """
    simple = filetool.file_to_simplename(filename)
    if prefix is None:
        return simple if filename.startswith("include_") else f"valueset_{simple}"
    return f"{prefix}{simple}"


def _action_to_dict(action: Action | dict) -> dict:
    if isinstance(action, SqlAction):
        return {
            "label": _clean_label(action.description),
            "type": action.build_type or "",
            "files": [_sql_file_entry(f) for f in action.file_list],
        }

    if isinstance(action, FileAction):
        return {
            "label": _clean_label(action.description),
            "type": action.build_type or "",
            "files": [f for f in action.file_list],
        }

    if isinstance(action, ExportAction):
        return {
            "label": _clean_label(action.description),
            "type": action.export_type or "",
            "tables": [
                item.stem if isinstance(item, Path) else item
                for item in action.file_list
            ],
        }

    if isinstance(action, dict):
        return action

    raise TypeError(
        f"{type(action).__name__} is not an [[actions]] entry "
        "(UploadAction is a whole submanifest: use save_upload_toml)"
    )

def _as_list(item):
    return item if isinstance(item, list) else [item]
