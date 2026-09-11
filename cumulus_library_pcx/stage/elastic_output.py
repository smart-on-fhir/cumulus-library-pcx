import os
from pathlib import Path
from cumulus_library_pcx.tools.settings import ENCOUNTER_REF
from cumulus_library_pcx.tools.fhir_reference import Aspect
from cumulus_library_pcx.tools import settings, manifest, tablespace, filetool, template, settings

#-----------------------------------------------------------------------------
# ElasticSearch output
#-----------------------------------------------------------------------------
def path_elastic_output() -> Path:
    """
    Workaround hack for
    https://github.com/smart-on-fhir/rapid-elastic/issues/29
    """
    output_base = settings.get_elastic_output_dir().resolve()
    return output_base / filetool.date_str()

def list_csv() -> list[Path]:
    """
    `elastic_query.py` >> elastic_output/*.csv
    """
    output_path = path_elastic_output()
    if output_path and output_path.exists():
        return list(output_path.glob('*.csv'))
    return list()

#-----------------------------------------------------------------------------
# ElasticSearch task
#-----------------------------------------------------------------------------
def list_tasks() -> list[Path]:
    tasks = ['casedef', 'task']
    tables = [tablespace.name_elastic(task) for task in tasks]
    return [filetool.path_athena(f"{table}.sql") for table in tables]

#-----------------------------------------------------------------------------
# TOML files
#-----------------------------------------------------------------------------
def path_upload_toml() -> Path:
    return path_elastic_output() / 'file_upload_elastic.toml'

def path_stage_toml() -> Path:
     return filetool.path_project() / 'elastic_output.toml'

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
def make_file_upload_toml() -> list[Path]:
    return [manifest.save_file_upload_toml(list_csv(), path_upload_toml(), prefix="elastic_")]

def make_union(aspect:Aspect=None) -> Path:
    cohort = f'union_{aspect.name}' if aspect else f'union'
    table_list = list_tables()
    return filetool.save_athena_view(
        tablespace.name_elastic(cohort),
        template.load(f"elastic_{cohort}.sql",
                      encounter_ref=ENCOUNTER_REF,
                      select_union=select_union(table_list))
    )

def make() -> list[Path]:
    if len(list_csv()) > 0:
        # Cumulus Library 6.3.1 prepends the study directory to action filenames.
        upload_file = os.path.relpath(path_upload_toml(), start=filetool.path_project())
        task_list = [make_union()]

        action_list = [manifest.FileAction(file_list=[upload_file],
                                           description='elastic_output CSV uploads',
                                           build_type='build:parallel'),
                       manifest.SqlAction(file_list=task_list,
                                          description='elastic_output union tasks',
                                          build_type='build:serial')]

        upload_toml = manifest.save_file_upload_toml(list_csv(), path_upload_toml(), prefix="elastic_")
        return [upload_toml, manifest.save_actions_toml(action_list, 'elastic_output.toml')]
    return list()

if __name__ == '__main__':
    for output_toml in make():
        print(output_toml)
