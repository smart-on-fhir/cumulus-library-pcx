from pathlib import Path
from cumulus_library_pcx.tools import filetool, tablespace, fhir_reference
from cumulus_library_pcx.tools.fhir_reference import Aspect, get_aspect
from cumulus_library_pcx.tools.manifest import (
    Action,
    UploadAction,
    FileAction,
    SqlAction,
    save_actions_toml
)

#-----------------------------------------------------------------------------
# Upload include_*.csv files
# Common: users add custom spreadsheet/*.csv files
# Rare: change the UPLOAD_FILE path; file contents are generated
#-----------------------------------------------------------------------------
UPLOAD_FILE = 'file_upload_study_variable.toml'

#-----------------------------------------------------------------------------
# List variables
#-----------------------------------------------------------------------------
def list_variables(aspect: str | Aspect = None) -> list[str]:
    """
    :param aspect: Aspect like Aspect.lab, Aspect.rx, etc
    :return: list of variables filtered by aspect
    """
    if not aspect:
        return _list_variables()
    elif isinstance(aspect, str):
        aspect = Aspect[aspect]
    return  [v for v in _list_variables() if get_aspect(v) == aspect]

def _list_variables() -> list[str]:
    """
    @refactor `study_variable.toml` is a better source of truth than the CSV files
    @refactor casedef as special variable case.

    List of valueset variable names not including "case definition".
    :return: sorted list of ValueSet variable names
    """
    var_list = filetool.filter_aspect(filetool.list_spreadsheet())
    var_list = [v.name for v in var_list]
    var_list = [v for v in var_list if "casedef" not in v]
    var_list = [filetool.file_to_simplename(v) for v in var_list]
    return sorted(list(set(var_list)))

def list_variables_as_str(variable_list:list[str], quote="'", seperator=',') -> str:
    """
    :param variable_list: variables to turn into a string
    :param quote: str default quote as 'item'
    :param seperator: str iterator over list
    """
    return tablespace.sql_quote(variable_list, quote, seperator)

def list_variable_uploads() -> list[Path]:
    return filetool.filter_aspect(filetool.list_spreadsheet())

#-----------------------------------------------------------------------------
# Aspect(s) for Variable
#-----------------------------------------------------------------------------
def list_aspect_names() -> list[str]:
    return [aspect.name for aspect in list_aspects()]

def list_aspects() -> list[Aspect]:
    """
    :return: list of aspects that have variables defined (dx, rx, diag, ...)
    """
    return list(dict_aspects().keys())

def dict_aspects() -> dict[Aspect, list[str]]:
    """
    Get a map of aspects so you can process "just labs", or "just rx".
    :return: dict like {'lab': ['lab_albumin', 'lab_crp', ...], 'rx': ['rx_azathioprine',....]}
    """
    out = {}
    for variable in list_variables():
        aspect = get_aspect(variable)
        if aspect not in out.keys():
            out[aspect] = [variable]
        else:
            out[aspect].append(variable)
    return out

#-----------------------------------------------------------------------------
# List tables
#-----------------------------------------------------------------------------
def list_tables() ->list[str]:
    """
    List tables (Athena SQL names) include valuesets and cohorts
    :return: list of table names
    """
    return list_tables_valueset() + list_tables_cohort()

def list_tables_valueset() ->list[str]:
    return [tablespace.name_valueset(v) for v in list_variables()]

def list_tables_cohort() ->list[str]:
    return [tablespace.name_cohort(v) for v in list_variables()]

def list_files() ->list[Path]:
    """
    List files output by stage `study_variable`
    :return: list of files for cohort
    """
    return [filetool.path_athena(file) for file in list_tables_cohort()]

#-----------------------------------------------------------------------------
# Cohort variable JOIN study population
#-----------------------------------------------------------------------------
def make_cohort(variable: str) -> Path:
    """
    :param variable: variable name (typically ValueSets)
    :return: str SQL create table for variable with metadata from corresponding study_population_{aspect}
    """
    col = fhir_reference.get_column(variable)

    population = tablespace.name_study_population(col.aspect.name)
    valueset_name = tablespace.name_valueset(variable)
    cohort_name = tablespace.name_cohort(variable)

    where = [f'{population}.{col.code} = {valueset_name}.code']
    if col.system:
        where+= [f'{population}.{col.system} = {valueset_name}.system']

    sql = tablespace.ctas(population, variable, where)
    return filetool.save_athena_view(cohort_name, sql)

#-----------------------------------------------------------------------------
# Actions
#-----------------------------------------------------------------------------
def make_upload(variable_list:list[str] | None) -> UploadAction:
    if not variable_list:
        variable_list = list_variables()
    return UploadAction(file_list=variable_list,
                        label='upload spreadsheet/*.csv valuesets')

def make_actions() -> list[Action]:
    """
    1. Make cohort for each variable
    2. Make cohort UNION variables as one big table
    3. Make cohort WIDE variables as one big table (tabular with each column is a variable)

    :return: list of TOML outputs
    """
    variable_list = [make_cohort(variable) for variable in list_variables()]

    return [FileAction(file_list=[f'../spreadsheet/{UPLOAD_FILE}'],
                       label=UPLOAD_FILE,
                       build_type='build:parallel'),
            SqlAction(file_list=variable_list,
                      label='variable cohorts')]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> list[Path]:
    return [save_actions_toml(make_actions(), 'study_variable.toml')]

if __name__ == '__main__':
    for output_toml in make():
        print(output_toml)
