import os
from pathlib import Path
from cumulus_library_pcx.tools.settings import ENCOUNTER_REF
from cumulus_library_pcx.tools.fhir_reference import Aspect
from cumulus_library_pcx.tools import settings, manifest, tablespace, filetool, template
from cumulus_library_pcx.tools.manifest import (
    Action,
    SqlAction,
    FileAction,
    UploadWorkflow
)

#-----------------------------------------------------------------------------
# Paths
#-----------------------------------------------------------------------------
UPLOAD_TOML = 'file_upload_elastic.toml'

def path_output() -> Path | None:
    """
    :return: $ELASTIC_OUTPUT_DIR if set, else $CUMULUS_LIBRARY_DATA_PATH/elastic/output
    """
    if settings.ELASTIC_OUTPUT_DIR:
        return Path(settings.ELASTIC_OUTPUT_DIR)
    if settings.CUMULUS_LIBRARY_DATA_PATH:
        return Path(settings.CUMULUS_LIBRARY_DATA_PATH) / 'elastic' / 'output'
    print('skipping optional elastic_upload stage, ELASTIC_OUTPUT_DIR not set')
    return None

#-----------------------------------------------------------------------------
# Template
#-----------------------------------------------------------------------------
def make_template_union(aspect:Aspect=None) -> Path:
    cohort = f'union_{aspect.name}' if aspect else f'union'
    table_list = list_tables()
    return filetool.save_athena_view(
        tablespace.name_elastic(cohort),
        template.load(f"elastic_{cohort}.sql",
                      encounter_ref=ENCOUNTER_REF,
                      select_union=select_union(table_list)))

#-----------------------------------------------------------------------------
# Helpers
#-----------------------------------------------------------------------------
def list_csv() -> list[Path]:
    output_path = path_output()
    if output_path and output_path.exists():
        return list(output_path.glob('*.csv'))
    return list()

def list_tables() -> list[str]:
    return [table_for_file(file) for file in list_csv()]

def table_for_file(filename:Path|str) -> str:
    return tablespace.name_elastic(filetool.file_to_simplename(filename))

def select_union(table_list: list[str]) -> str:
    sql = list()
    for table in table_list:
        topic = tablespace.name_trim(table)
        select = f"\tSELECT '{topic}'\t AS topic, * FROM {table}"
        sql.append(select)
    return ' UNION ALL\n'.join(sql)

#-----------------------------------------------------------------------------
# UploadWorkflow
#-----------------------------------------------------------------------------
def make_upload_toml() -> Path:
    return manifest.save_upload_toml(
        workflow=UploadWorkflow(file_list=list_csv(), prefix='elastic_'),
        toml_file=path_output() / UPLOAD_TOML)

#-----------------------------------------------------------------------------
# Actions
#-----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    if len(list_csv()) == 0:
        return list()

    upload_toml = path_output() / UPLOAD_TOML
    upload_toml = os.path.relpath(upload_toml, start=filetool.path_project())
    task_list = [make_template_union()]

    return  [FileAction(file_list=[upload_toml],
                        label='elastic_output CSV uploads'),
             SqlAction(file_list=task_list,
                       label='elastic_output union tasks')]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return manifest.save_actions_toml(make_actions(), 'elastic_upload.toml')

if __name__ == '__main__':
    print(make())
