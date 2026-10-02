"""Study-owned SQL; clinical definitions are preserved from the source study."""
from cumulus_study_builder.tools import sql_stage, toml_tool, filetool
from cumulus_study_builder.tools.actions import FileAction, UploadWorkflow

FILES = ['outcome/outcome_vital_status.sql', 'outcome/outcome_first_event.sql', 'outcome/outcome_exposure.sql', 'outcome/outcome.sql']


def make():
    path = sql_stage.make('outcome', FILES, exports=[])
    return path
