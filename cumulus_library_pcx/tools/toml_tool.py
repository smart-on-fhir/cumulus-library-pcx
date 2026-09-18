import tomllib
import tomli_w
from pathlib import Path
from functools import lru_cache
from cumulus_library import StudyManifest
from cumulus_library_pcx.tools import filetool
from cumulus_library_pcx.tools.tablespace import PREFIX
from cumulus_library_pcx.tools.actions import (
    Stage,
    Action,
    FileAction,
    UploadWorkflow,
    SqlAction,
    SqlParallelAction,
    ExportAction
)

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
# TOML builders
#-----------------------------------------------------------------------------
def as_manifest_toml(stages: list[Stage],
                     study_prefix: str = PREFIX,
                     data_dictionary: str = '../spreadsheet/data_dictionary.csv') -> dict:
    """
    Build a Python dict for the top-level manifest.toml, stages in build order.
    """
    stage_tables = dict()
    for stage in stages:
        entry = dict()   # tomli-w keeps this key order
        if stage.skip_by_default:
            entry['skip_by_default'] = True
        if stage.submanifest:
            entry['type'] = 'submanifest'
        entry['files'] = list(stage.files)
        stage_tables[stage.name] = [entry]
    return {
        'study_prefix': study_prefix,
        'data_dictionary': data_dictionary,
        'stages': stage_tables,
    }

def as_actions_toml(actions: Action| list[ Action | dict]) -> dict:
    """
    Build a Python dict for a mixed list of SQL and export actions.

    This is useful when one manifest contains both build and export actions.
    """
    return {"actions": [_action_to_dict(action) for action in _as_list(actions)]}

def as_upload_toml(workflow: UploadWorkflow) -> dict:
    """
    Build a Python dict for a file_upload workflow TOML.

    :param workflow: upload workflow (file_list of CSVs, optional table-name prefix)
    :return: dict content for the workflow TOML
    """
    tables: dict[str, dict[str, str]] = {}

    for filename in workflow.file_list:
        filename = Path(filename).name
        table_name = _upload_table_name(filename, workflow.prefix)
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


def save_manifest_toml(stages: list[Stage], toml_file: Path | str = 'manifest.toml') -> Path:
    """
    Save the top-level manifest.toml; string filenames are relative to the project directory.
    """
    if not isinstance(toml_file, Path):
        toml_file = filetool.path_project(toml_file)
    return _write_toml(as_manifest_toml(stages), toml_file)


def save_actions_toml(actions: Action | list[Action | dict], toml_file: Path | str) -> Path:
    """
    Save an `[[actions]]` manifest; string filenames are relative to the project directory.
    """
    if not isinstance(toml_file, Path):
        toml_file = filetool.path_project(toml_file)
    return _write_toml(as_actions_toml(actions), toml_file)


def save_upload_toml(workflow: UploadWorkflow, toml_file: Path | str) -> Path:
    """
    Save a file_upload workflow TOML; string filenames are relative to the spreadsheet directory.
    """
    if not isinstance(toml_file, Path):
        toml_file = filetool.path_spreadsheet(toml_file)
    return _write_toml(as_upload_toml(workflow), toml_file)


def _write_toml(content: dict, toml_file: Path) -> Path:
    """
    Serialize with tomli-w (no hand-quoted strings or lists) and write to disk.
    """
    return filetool.write_text(tomli_w.dumps(content).strip() + "\n", toml_file)

#-----------------------------------------------------------------------------
# TOML helpers
#-----------------------------------------------------------------------------
def _clean_label(label: str | None = None) -> str:
    """
    Cumulus Library rejects square brackets in an action label (reserved characters).
    """
    if not label:
        return ""
    return label.replace("[", "(").replace("]", ")")

def _sql_file_entry(file: Path | str) -> str:
    """
    TOML `files` entry for one SQL file, relative to the project directory.
    Generated SQL lives in athena/, study-specific hand-written SQL lives in custom/,
    LLM wide tables live in llm/athena/, QA and example tables live in ../tests/athena/.
    """
    path = Path(file)
    parent = path.parent.resolve()
    if parent == filetool.path_custom().resolve():
        return f"custom/{path.name}"
    if parent == filetool.path_llm_athena().resolve():
        return f"llm/athena/{path.name}"
    if parent == filetool.path_tests_athena().resolve():
        return f"../tests/athena/{path.name}"
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
            "label": _clean_label(action.label),
            "type": action.build_type or "",
            "files": [_sql_file_entry(f) for f in action.file_list],
        }

    if isinstance(action, FileAction):
        return {
            "label": _clean_label(action.label),
            "type": action.build_type or "",
            "files": [f for f in action.file_list],
        }

    if isinstance(action, ExportAction):
        return {
            "label": _clean_label(action.label),
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
        "(a workflow such as UploadWorkflow is saved with save_upload_toml)"
    )

def _as_list(item):
    return item if isinstance(item, list) else [item]
