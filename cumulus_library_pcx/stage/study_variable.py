"""Variable stage: upload valuesets, then build their cohort tables.

Discovery, naming and SQL generation live in tools.variable_tool. This module
owns the action order and the manifests that expose the stage to Cumulus.
"""
from pathlib import Path

from cumulus_library_pcx.tools import variable_tool
from cumulus_library_pcx.tools.actions import Action, FileAction, SqlAction, UploadWorkflow
from cumulus_library_pcx.tools.toml_tool import save_actions_toml, save_upload_toml

UPLOAD_TOML = 'file_upload_study_variable.toml'
STAGE_TOML = 'study_variable.toml'


def make_actions() -> list[Action]:
    """Prepare cohort SQL and assemble upload-before-cohort build actions."""
    return [
        FileAction(file_list=[f'../spreadsheet/{UPLOAD_TOML}'], label=UPLOAD_TOML),
        SqlAction(file_list=variable_tool.make_cohorts(), label='variable cohorts'),
    ]

def make() -> Path:
    """Write the valueset upload workflow and the variable stage manifest."""
    save_upload_toml(
        UploadWorkflow(file_list=variable_tool.list_variable_uploads()), UPLOAD_TOML,
    )
    return save_actions_toml(make_actions(), STAGE_TOML)
