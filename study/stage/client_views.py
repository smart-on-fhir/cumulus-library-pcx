"""Study-owned SQL; clinical definitions are preserved from the source study."""
from cumulus_study_builder.tools import sql_stage, toml_tool, filetool
from cumulus_study_builder.tools.actions import FileAction, UploadWorkflow

FILES = ['client_views/client_subject.sql', 'client_views/client_diagnosis.sql', 'client_views/client_encounter.sql', 'client_views/client_exposure.sql', 'client_views/client_timeline.sql', 'client_views/client_timeline_latest.sql', 'client_views/client_outcome.sql', 'client_views/client_dictionary_coverage.sql']


def make():
    toml_tool.save_upload_toml(UploadWorkflow([filetool.path_spreadsheet(p) for p in ['client_dictionary.csv']], prefix=''), filetool.path_spreadsheet('file_upload_client_views.toml'))
    path = sql_stage.make('client_views', FILES, exports=['client_subject', 'client_diagnosis', 'client_encounter', 'client_exposure', 'client_timeline', 'client_outcome', 'client_dictionary_coverage'])
    content = toml_tool.load_toml(path)
    content["actions"][:0] = toml_tool.as_actions_toml(FileAction(['../spreadsheet/file_upload_client_views.toml'], "Study inputs"))["actions"]
    toml_tool.save_actions_toml(content['actions'], path)
    return path
