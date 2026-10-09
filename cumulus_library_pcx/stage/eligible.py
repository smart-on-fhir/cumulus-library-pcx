"""Study-owned SQL; clinical definitions are preserved from the source study."""
from cumulus_study_builder.tools import sql_stage, toml_tool, filetool
from cumulus_study_builder.tools.actions import FileAction, UploadWorkflow

FILES = ['eligible_dx.sql', 'eligible_surgery.sql', 'eligible_rx.sql', 'eligible_radiation.sql', 'eligible.sql', 'eligible_trial.sql']


def make():
    path = sql_stage.make('eligible', FILES, exports=[])
    return path
