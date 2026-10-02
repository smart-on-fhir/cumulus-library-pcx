"""Study-owned SQL; clinical definitions are preserved from the source study."""
from cumulus_study_builder.tools import sql_stage, toml_tool, filetool
from cumulus_study_builder.tools.actions import FileAction, UploadWorkflow

FILES = ['eligible/eligible_dx.sql', 'eligible/eligible_surgery.sql', 'eligible/eligible_rx.sql', 'eligible/eligible_radiation.sql', 'eligible/eligible.sql', 'eligible/eligible_trial.sql']


def make():
    path = sql_stage.make('eligible', FILES, exports=[])
    return path
