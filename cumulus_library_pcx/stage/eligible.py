"""Study-owned SQL; clinical definitions are preserved from the source study."""
from cumulus_study_builder.tools import sql_stage, toml_tool, filetool
from cumulus_study_builder.tools.actions import FileAction, UploadWorkflow

SQL_FILE_LIST = ['pcx__llm_note_date.sql',
                 'pcx__systemic_therapy_protocol.sql',
                 'pcx__exposure_record.sql',
                 'eligible_dx.sql',
                 'eligible_surgery.sql',
                 'eligible_rx.sql',
                 'eligible_radiation.sql',
                 'eligible.sql',
                 'eligible_trial.sql']

def make():
    # include_trial_protocol.csv becomes pcx__include_trial_protocol, read by pcx__systemic_therapy_protocol
    toml_tool.save_upload_toml(UploadWorkflow([filetool.path_spreadsheet('include_trial_protocol.csv')]),
                               filetool.path_spreadsheet('file_upload_eligible.toml'))
    path = sql_stage.make('eligible', SQL_FILE_LIST, exports=[])
    content = toml_tool.load_toml(path)
    content["actions"][:0] = toml_tool.as_actions_toml(FileAction(['../spreadsheet/file_upload_eligible.toml'], "Study inputs"))["actions"]
    toml_tool.save_actions_toml(content['actions'], path)
    return path
