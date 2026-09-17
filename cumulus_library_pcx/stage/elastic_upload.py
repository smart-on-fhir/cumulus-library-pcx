import os
from pathlib import Path
from cumulus_library_pcx.tools.settings import ENCOUNTER_REF
from cumulus_library_pcx.tools.fhir_reference import Aspect
from cumulus_library_pcx.tools import settings, manifest, tablespace, filetool, template

#-----------------------------------------------------------------------------
# Paths
#-----------------------------------------------------------------------------
UPLOAD_TOML = 'file_upload_elastic.toml'

def path_upload_toml() -> Path:
    return path_output() / UPLOAD_TOML

def path_output() -> Path:
    """
    :return: $ELASTIC_OUTPUT_DIR if set, else $CUMULUS_LIBRARY_DATA_PATH/elastic/output
    """
    if settings.ELASTIC_OUTPUT_DIR:
        return Path(settings.ELASTIC_OUTPUT_DIR)
    if settings.CUMULUS_LIBRARY_DATA_PATH:
        return Path(settings.CUMULUS_LIBRARY_DATA_PATH) / 'elastic' / 'output'
    raise EnvironmentError("ELASTIC_OUTPUT_DIR or CUMULUS_LIBRARY_DATA_PATH must be set")

#-----------------------------------------------------------------------------
# List results
#-----------------------------------------------------------------------------
def list_csv() -> list[Path]:
    output_path = path_output()
    if output_path and output_path.exists():
        return list(output_path.glob('*.csv'))
    return list()

#-----------------------------------------------------------------------------
# ElasticSearch task
#-----------------------------------------------------------------------------
def list_tasks() -> list[Path]:
    tasks = ['casedef']
    tables = [tablespace.name_elastic(task) for task in tasks]
    return [filetool.path_athena(f"{table}.sql") for table in tables]

#-----------------------------------------------------------------------------
# Helpers
#-----------------------------------------------------------------------------
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
# Make
#-----------------------------------------------------------------------------
def make_upload() -> manifest.UploadAction:
    return manifest.UploadAction(file_list=list_csv(),
                                 label='elastic_output CSV uploads',
                                 prefix='elastic_')

def make_file_upload_toml() -> list[Path]:
    return [manifest.save_upload_toml(make_upload(), path_upload_toml())]

def make_union(aspect:Aspect=None) -> Path:
    cohort = f'union_{aspect.name}' if aspect else f'union'
    table_list = list_tables()
    return filetool.save_athena_view(
        tablespace.name_elastic(cohort),
        template.load(f"elastic_{cohort}.sql",
                      encounter_ref=ENCOUNTER_REF,
                      select_union=select_union(table_list)))

def make() -> list[Path]:
    if len(list_csv()) > 0:
        # Cumulus Library 6.3.1 prepends the study directory to action filenames.
        upload_file = os.path.relpath(path_upload_toml(), start=filetool.path_project())
        task_list = [make_union()]

        upload = make_upload()
        action_list = [manifest.FileAction(file_list=[upload_file],
                                           label=upload.label),
                       manifest.SqlAction(file_list=task_list,
                                          label='elastic_output union tasks')]

        upload_toml = manifest.save_upload_toml(upload, path_upload_toml())
        return [upload_toml, manifest.save_actions_toml(action_list, 'elastic_output.toml')]
    return list()

if __name__ == '__main__':
    for output_toml in make():
        print(output_toml)
