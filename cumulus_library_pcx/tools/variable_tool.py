"""Variable discovery, grouping, naming and cohort generation.

Core helpers accept explicit files and table names. Convenience functions use
the checkout's filetool/tablespace settings when no files are supplied, so stages
and other consumers share discovery without importing one another.
"""
from collections.abc import Iterable
from pathlib import Path

from cumulus_library_pcx.tools.fhir_reference import Aspect, Column
from cumulus_library_pcx.tools import (
    settings,
    filetool,
    fhir_reference,
    tablespace,
    template
)

#-----------------------------------------------------------------------------
# List
#-----------------------------------------------------------------------------
def list_uploads(files: Iterable[Path], *, exclude: str) -> list[Path]:
    """Keep aspect-named variable files, preserving the caller's file order."""
    aspects = set(fhir_reference.list_aspect())
    return [path for path in files
            if '_' in path.name and path.name.split('_')[0] in aspects
            and exclude not in path.name]


def list_variables(files: Iterable[Path] | None = None,
                   aspect: str | Aspect | None = None) -> list[str]:
    """Sorted variable names; explicit files are already selected upload files."""
    if files is None:
        files = list_variable_uploads()
    names = sorted({path.name.split('.')[0] for path in files})
    if not aspect:
        return names
    if isinstance(aspect, str):
        aspect = Aspect[aspect]
    return [name for name in names if fhir_reference.get_aspect(name) == aspect]

#-----------------------------------------------------------------------------
# List
#-----------------------------------------------------------------------------

def group_aspects(names: Iterable[str]) -> dict[Aspect, list[str]]:
    """Group names without changing their order."""
    groups = {}
    for name in names:
        groups.setdefault(fhir_reference.get_aspect(name), []).append(name)
    return groups


def ctas_cohort(population: str, valueset: str, cohort: str, column: Column) -> str:
    """Render a coded cohort join using explicit source and destination names."""
    where = [f'{population}.{column.code} = {valueset}.code']
    if column.system:
        where.append(f'{population}.{column.system} = {valueset}.system')
    sources = tablespace.sql_list([population, valueset])
    return '\n'.join([f'CREATE TABLE {cohort} AS ',
                      f'SELECT DISTINCT * FROM \n {sources}',
                      'WHERE', tablespace.sql_and(where)])


# Checkout adapters: the pure helpers above also support other studies directly.
def list_variable_uploads(files: Iterable[Path] | None = None,
                          *, exclude: str = 'casedef') -> list[Path]:
    """Discover variable valuesets, excluding the separately built case definition."""
    return list_uploads(filetool.list_spreadsheet() if files is None else files,
                        exclude=exclude)


def list_variables_as_str(variable_list: list[str], quote="'", seperator=',') -> str:
    """Format SQL values; retain the historical keyword spelling for callers."""
    return tablespace.sql_quote(variable_list, quote, seperator)


def dict_aspects(files: Iterable[Path] | None = None) -> dict[Aspect, list[str]]:
    return group_aspects(list_variables(files))


def list_aspects(files: Iterable[Path] | None = None) -> list[Aspect]:
    return list(dict_aspects(files))


def list_aspect_names(files: Iterable[Path] | None = None) -> list[str]:
    return [aspect.name for aspect in list_aspects(files)]


def list_tables_valueset(files: Iterable[Path] | None = None) -> list[str]:
    return [tablespace.name_valueset(name) for name in list_variables(files)]


def list_tables_cohort(files: Iterable[Path] | None = None) -> list[str]:
    return [tablespace.name_cohort(name) for name in list_variables(files)]


def list_tables(files: Iterable[Path] | None = None) -> list[str]:
    # Materialize once so one-shot iterables produce both table groups.
    uploads = list(files) if files is not None else list_variable_uploads()
    return list_tables_valueset(uploads) + list_tables_cohort(uploads)


def list_files(files: Iterable[Path] | None = None) -> list[Path]:
    """Return legacy cohort paths (without adding a SQL extension)."""
    return [filetool.path_athena(name) for name in list_tables_cohort(files)]


def make_cohort(variable: str) -> Path:
    """Render and save one variable cohort using the checkout's naming rules."""
    column = fhir_reference.get_column(variable)
    cohort = tablespace.name_cohort(variable)
    sql = ctas_cohort(
        population=tablespace.name_study_population(column.aspect.name),
        valueset=tablespace.name_valueset(variable),
        cohort=cohort,
        column=column,
    )
    return filetool.save_athena_view(cohort, sql)


def make_cohorts(files: Iterable[Path] | None = None) -> list[Path]:
    return [make_cohort(name) for name in list_variables(files)]


#-----------------------------------------------------------------------------
# Template WIDE
#-----------------------------------------------------------------------------
def make_wide_bool(aspect:Aspect=None) -> Path:
    """
    All study variable cohorts in one table in WIDE format.
    each variable has a single column denoting
        True == present variable per encounter
        False == absent variable per encounter

    :return: Path to SQL file
    """
    cohort = f'variable_wide_{aspect.name}' if aspect else f'variable_wide'
    variable_list = list_variables(aspect=aspect)
    return filetool.save_athena_view(
        tablespace.name_cohort(cohort),
        template.load(f"cohort_{cohort}.sql",
                      encounter_ref=settings.ENCOUNTER_REF,
                      select_wide_bool=select_wide_bool(variable_list),
                      select_wide_any=select_wide_any(variable_list)))

def select_wide_bool(variable_list: list[str]) -> str:
    """
    "Wide" turns each variable value into a named column,
    "bool" denotes variable present(True) or absent(False).

    @refactor to Jinja template
    :param variable_list: variable names (typically list of valuesets)
    :return: str SQL select variable table as column name
    """
    sql = list()
    for variable in variable_list:
        variable = tablespace.name_trim(variable)
        sql.append(f"\t\tIF(variable='{variable}', True, NULL) AS {variable}")
    return '\t'+ ',\n'.join(sql).strip()

def select_wide_any(variable_list: list[str]) -> str:
    """
    "Wide" variable is expected to already be a binary column.
    "any" denotes variable is present(True) at least once (1+).

    Select "arbitrary" is an optimization that compresses rows such that if a single
    variable instance is found for an encounter_ref, the search condition is reached (1+),
    table search ends, allowing for the next variable search.

    https://prestodb.io/docs/current/functions/aggregate.html#arbitrary-x-same-as-input

    @refactor to Jinja template
    :param variable_list: variable names (typically list of valuesets)
    :return: str SQL select variable for any arbitrary match
    """
    sql = list()
    for variable in variable_list:
        variable = tablespace.name_trim(variable)
        sql.append(f"\t\tarbitrary({variable}) FILTER (where {variable} ) as {variable}")
    return '\t' + ',\n'.join(sql).strip()

#-----------------------------------------------------------------------------
# Template WIDE for each aspect
#-----------------------------------------------------------------------------
def make_wide() -> list[Path]:
    """
    :return: list of SQL files for each aspect
            * cohort_variable_wide_lab
            * cohort_variable_wide_diag
            * cohort_variable_wide_dx
            * cohort_variable_wide_rx
    """
    return [_make_wide(aspect) for aspect in list_aspects()]

def _make_wide(aspect:Aspect, generator=None) -> Path:
    """
    :param aspect: aspect to make variable wide for
    :param generator: select_wide_*** function
    :return: Path to SQL file
    """
    if not generator:
        if aspect == Aspect.dx:
            return _make_wide(aspect, select_wide_dx)
        elif aspect == Aspect.lab:
            return _make_wide(aspect, select_wide_lab)
        elif aspect == Aspect.diag:
            return _make_wide(aspect, select_wide_diag)
        elif aspect == Aspect.doc:
            return _make_wide(aspect, select_wide_doc)
        elif aspect == Aspect.rx:
            return _make_wide(aspect, select_wide_rx)
        elif aspect == Aspect.proc:
            return _make_wide(aspect, select_wide_proc)
        elif aspect == Aspect.enc:
            return _make_wide(aspect, select_wide_enc)
        else:
            raise NotImplementedError(f"'{aspect}' aspect type not yet supported.")
    else:
        cohort = f'variable_wide_{aspect.name}'
        return filetool.save_athena_view(
            tablespace.name_cohort(cohort),
            template.load(f"cohort_variable_wide_aspect.sql",
                          encounter_ref=settings.ENCOUNTER_REF,
                          aspect=aspect.name,
                          select_wide_dict=generator()))

#-----------------------------------------------------------------------------
# Template UNION
#-----------------------------------------------------------------------------
def make_union_bool() -> list[Path]:
    """
    1.1 Create table of all variable cohorts together (UNION ALL) having a single column
        `variable` which denotes the cohort source.

    :return: path to cohort_variable_union.sql
    """
    return [_make_union(aspect=None)]

def make_union_aspect() -> list[Path]:
    """
    1.2 Create tables of variables grouped by Aspect

    :return: [cohort_variable_union_lab.sql,
             cohort_variable_union_diag.sql,
             cohort_variable_union_doc.sql,
             cohort_variable_union_rx.sql]
    """
    return [_make_union(aspect=aspect) for aspect in list_aspects()]

def _make_union(aspect:Aspect=None) -> Path:
    """
    :param aspect: variable types to union, or None= all variables
    :return: Path to SQL file
    """
    cohort = f'variable_union_{aspect.name}' if aspect else f'variable_union'
    variable_list = list_variables(aspect=aspect)
    return filetool.save_athena_view(
        tablespace.name_cohort(cohort),
        template.load(f"cohort_{cohort}.sql",
                      encounter_ref=settings.ENCOUNTER_REF,
                      select_union=select_union(variable_list),
                      variable_list=list_variables_as_str(variable_list)))

def select_union(variable_list: list[str]) -> str:
    """
    @refactor to Jinja template
    Get SQL select UNION ALL statement from a list of variable names.

    :param variable_list: variable names (typically list of valuesets)
    :return: str SQL select UNION ALL for the provided variable list
    """
    sql = list()
    for variable in variable_list:
        variable = tablespace.name_trim(variable)
        select = f"\tSELECT '{variable}'\t AS variable, code, display, system, {settings.ENCOUNTER_REF}"
        select+= f", {fhir_reference.get_column(variable).reference} AS resource_ref"
        from_table = f" FROM {tablespace.PREFIX}__cohort_{variable}"
        sql.append(select + from_table)
    return ' UNION ALL\n'.join(sql)

#-----------------------------------------------------------------------------
# Wide
#-----------------------------------------------------------------------------
def select_wide_dict(variable_list:list[str], columns:dict) -> str:
    """
    Generic helper method for turning a single variable column into multiple columns.

    "Wide" denotes turning a variable value into column(s),
    "dict" denotes Key=Val pairs of the original column name to wide column name.

    :param variable_list: any variable name like `diag_mre_enterography`
    :param columns: study population column names with simple suffix value
    :return: string SQL
    """
    sql = list()
    for variable in variable_list:
        for key, val in columns.items():
            sql.append(f"IF(variable='{variable}', {key}, NULL) AS {variable}_{val}")
    return ',\n'.join(sql).strip()

def select_wide_dx(variable_list: list[str] = None, columns: dict = None) -> str:
    """
    FHIR Condition attributes
    * https://build.fhir.org/condition-definitions.html#Condition.clinicalStatus
    * https://build.fhir.org/condition-definitions.html#Condition.onset_x_
    * https://build.fhir.org/condition-definitions.html#Condition.category

    :param variable_list: default= Dx variables
    :param columns: default Dx
    :return: str SQL
    """
    if not variable_list:
        variable_list = list_variables(aspect=Aspect.dx)
    if not columns:
        columns = {'dx_onset_date': 'onset',
                   'dx_category_code':'category',
                   'dx_clinical_status': 'status',
                   'condition_ref': 'ref'}
    return select_wide_dict(variable_list, columns)

def select_wide_rx(variable_list: list[str] = None, columns: dict = None) -> str:
    """
    FHIR MedicationRequest attributes
    * https://build.fhir.org/medicationrequest-definitions.html#MedicationRequest.status
    * https://build.fhir.org/medicationrequest-definitions.html#MedicationRequest.category
    * https://build.fhir.org/medicationrequest-definitions.html#MedicationRequest.authoredOn

    :param variable_list: default=medication variables
    :param columns: default Rx status, category, authoredOn, and FHIR reference
    :return: str SQL
    """
    if not variable_list:
        variable_list = list_variables(aspect=Aspect.rx)
    if not columns:
        columns = {'rx_authoredon_date': 'date',
                   'rx_status': 'status',
                   'rx_category_code': 'category',
                   'medicationrequest_ref': 'ref'}
    return select_wide_dict(variable_list, columns)

def select_wide_lab(variable_list: list[str]=None, columns:dict = None) -> str:
    """
    FHIR Observation('laboratory') attributes
    * https://build.fhir.org/observation-definitions.html#Observation.effective_x_
    * https://build.fhir.org/observation-definitions.html#Observation.interpretation
    * https://build.fhir.org/observation-definitions.html#Observation.value_x_

    :param variable_list: default= Laboratory variables
    :param columns: default= effective date, interpretation, value, unit, FHIR reference
    :return: str SQL
    """
    if not variable_list:
        variable_list = list_variables(aspect=Aspect.lab)
    if not columns:
        columns = {'lab_effectivedate': 'date',
                   'lab_interpretation_code': 'interpretation',
                   'lab_valuequantity_value': 'value',
                   'lab_valuequantity_unit': 'unit',
                   'observation_ref': 'ref'}
    return select_wide_dict(variable_list, columns)

def select_wide_enc(variable_list: list[str] = None, columns: dict = None) -> str:
    """
    FHIR Encounter attributes

    :param variable_list: default= Diagnostic report variables
    :param columns: default = effective date, code, FHIR reference
    :return: str SQL
    """
    if not variable_list:
        variable_list = list_variables(aspect=Aspect.enc)
    if not columns:
        columns = {'encounter_ref': 'ref'}
    return select_wide_dict(variable_list, columns)

def select_wide_diag(variable_list: list[str] = None, columns: dict = None) -> str:
    """
    FHIR DiagnosticReport attributes
    * https://build.fhir.org/diagnosticreport-definitions.html#DiagnosticReport.category
    * https://build.fhir.org/diagnosticreport-definitions.html#DiagnosticReport.code
    * https://build.fhir.org/diagnosticreport-definitions.html#DiagnosticReport.effective_x_

    :param variable_list: default= Diagnostic report variables
    :param columns: default = effective date, code, FHIR reference
    :return: str SQL
    """
    if not variable_list:
        variable_list = list_variables(aspect=Aspect.diag)
    if not columns:
        columns = {'diag_effectivedatetime_day': 'date',
                   'diag_code': 'code',
                   'diagnosticreport_ref': 'ref'}
    return select_wide_dict(variable_list, columns)

def select_wide_doc(variable_list: list[str] = None, columns: dict = None) -> str:
    """
    FHIR DocumentReference
    * https://build.fhir.org/documentreference.html

    :param variable_list: default = Document Reference variables
    :param columns: default= author date, code
    :return: str SQL
    """
    if not variable_list:
        variable_list = list_variables(aspect=Aspect.doc)
    if not columns:
        columns = {'doc_author_day': 'date',
                   'doc_type_code': 'code',
                   'documentreference_ref': 'ref'}
    return select_wide_dict(variable_list, columns)

def select_wide_proc(variable_list: list[str] = None, columns: dict = None) -> str:
    """
    FHIR Procedure
    * https://build.fhir.org/procedure.html
    * https://build.fhir.org/procedure-definitions.html#Procedure.performer.period
    * https://build.fhir.org/procedure-definitions.html#Procedure.category

    :param variable_list: default = Procedure variables
    :param columns: default= author date, code
    :return: str SQL
    """
    if not variable_list:
        variable_list = list_variables(aspect=Aspect.proc)
    if not columns:
        columns = {'proc_performed_day': 'date',
                   'proc_category_code': 'code',
                   'procedure_ref': 'ref'}
    return select_wide_dict(variable_list, columns)