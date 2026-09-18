"""Variable discovery, grouping, naming and cohort generation.

Core helpers accept explicit files and table names. Convenience functions use
the checkout's filetool/tablespace settings when no files are supplied, so stages
and other consumers share discovery without importing one another.
"""
from collections.abc import Iterable
from pathlib import Path

from cumulus_library_pcx.tools import filetool, fhir_reference, tablespace
from cumulus_library_pcx.tools.fhir_reference import Aspect, Column


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


def group_aspects(names: Iterable[str]) -> dict[Aspect, list[str]]:
    """Group names without changing their order."""
    groups = {}
    for name in names:
        groups.setdefault(fhir_reference.get_aspect(name), []).append(name)
    return groups


def cohort_sql(population: str, valueset: str, cohort: str, column: Column) -> str:
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
    sql = cohort_sql(
        population=tablespace.name_study_population(column.aspect.name),
        valueset=tablespace.name_valueset(variable),
        cohort=cohort,
        column=column,
    )
    return filetool.save_athena_view(cohort, sql)


def make_cohorts(files: Iterable[Path] | None = None) -> list[Path]:
    return [make_cohort(name) for name in list_variables(files)]
