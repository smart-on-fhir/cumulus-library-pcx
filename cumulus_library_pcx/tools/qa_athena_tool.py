"""QA tables: find the qa, warn and example SQL in tests/athena and render their union SQL.

Three kinds of table, named by prefix:
    pcx__qa_*        must have zero rows; any row is a failure
    pcx__warn_*      rows are findings to eyeball, not failures
    pcx__example_*   user-facing examples built only from client tables
pcx__qa_union and pcx__warn_union count the rows of every qa / warn table.

The first three functions are study-independent: they take explicit paths and
table names. The rest are checkout adapters that supply this study's folders and
prefix. The stage (stage/qa_athena.py) owns the action order and qa_athena.toml.
"""
from collections.abc import Iterable
from pathlib import Path

from cumulus_library_pcx.tools import filetool, tablespace, template

#-----------------------------------------------------------------------------
# Templates: tests/template/<name>.sql.jinja -> tests/athena/<render>>.sql
#-----------------------------------------------------------------------------
def list_templates() -> list[Path]:
    return list_sql(filetool.path_tests_template(), '*.sql.jinja')

def save_templates() -> list[Path]:
    """Render every test template; returns the tests/athena SQL written."""
    out = list()
    for sql_template in list_templates():
        out.append(template.save_test(sql_template))
    return out

#-----------------------------------------------------------------------------
# SQL tables
#-----------------------------------------------------------------------------
def list_tables(files: Iterable[Path]) -> list[str]:
    return [path.stem for path in files]

def list_tables_qa() -> list[str]:
    return list_tables(list_qa())

def list_tables_warn() -> list[str]:
    return list_tables(list_warn())

def list_tables_example() -> list[str]:
    return list_tables(list_example())

def ctas_union_all(table: str, source_tables: Iterable[str]) -> str:
    """One count row per source table, retaining the supplied dependency order."""
    selects = [f"SELECT COUNT(*) as cnt, '{source}' AS test \n FROM {source}"
               for source in source_tables]
    return f'CREATE TABLE {table} AS \n' + '\n UNION ALL \n'.join(selects)

#-----------------------------------------------------------------------------
# SQL files
#-----------------------------------------------------------------------------
def list_sql(directory: Path, pattern: str, exclude: str | None = None) -> list[Path]:
    """Sorted matching paths; an exclusion is a substring of the complete path.

    None disables exclusion. An empty string retains the legacy match-all
    exclusion behavior for callers that explicitly pass it.
    """
    return sorted(path for path in directory.glob(pattern)
                  if exclude is None or exclude not in str(path))

def list_athena(wildcard: str, exclude: str | None = None) -> list[Path]:
    """
    list_athena('warn_*.sql') -> tests/athena/pcx__warn_*.sql, sorted
    :param exclude: substring of paths to leave out, e.g. the union table's own file
    """
    return list_sql(filetool.path_tests_athena(), tablespace.name_prefix(wildcard), exclude)

def list_qa() -> list[Path]:
    return list_athena('qa_*.sql', tablespace.name_prefix('qa_union.sql'))

def list_warn() -> list[Path]:
    return list_athena('warn_*.sql', tablespace.name_prefix('warn_union.sql'))

def list_example() -> list[Path]:
    return list_athena('example_*.sql', tablespace.name_prefix('example_union.sql'))

#-----------------------------------------------------------------------------
# Union: one count row per qa / warn table
#-----------------------------------------------------------------------------
def make_union_table(union_table: str, file_list: list[Path]) -> Path:
    """make_union_table('qa_union', list_qa()) -> tests/athena/pcx__qa_union.sql"""
    table = tablespace.name_prefix(union_table)
    sql = ctas_union_all(table, list_tables(file_list))
    return filetool.write_text(sql, filetool.path_tests_athena(f'{table}.sql'))

def make_union() -> list[Path]:
    return [make_union_table('qa_union', list_qa()),
            make_union_table('warn_union', list_warn())]
