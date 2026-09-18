"""
Every SQL file the study ships parses as one Trino (Athena) statement.

No tables and no database: this catches what goes wrong in generated and hand-written SQL,
a Jinja render that leaves a trailing comma or an unbalanced parenthesis, a semicolon inside
a comment (cumulus-library splits on it), a keyword typo, an Athena-invalid construct.
sqlglot is permissive on its own (a typo falls back to an opaque Command, a trailing comma
is dropped), so those two get explicit checks.
"""
import re
import pytest
import sqlglot
from sqlglot import exp
from sqlglot.errors import ParseError
from cumulus_library_pcx.tools import filetool

SQL_DIRS = {
    'athena': filetool.path_athena(),
    'custom': filetool.path_custom(),
    'llm/athena': filetool.path_llm_athena(),
    'tests/athena': filetool.path_tests_athena(),
}

TRAILING_COMMA = re.compile(
    r',\s*(FROM\b|WHERE\b|GROUP\s+BY|ORDER\s+BY|HAVING\b|UNION\b|LIMIT\b|\))',
    re.IGNORECASE)

def sql_files() -> list:
    out = list()
    for label, directory in SQL_DIRS.items():
        for path in sorted(directory.glob('*.sql')):
            out.append(pytest.param(path, id=f'{label}/{path.name}'))
    return out

def strip_comments(sql: str) -> str:
    return re.sub(r'--[^\n]*', '', sql)

@pytest.mark.parametrize('path', sql_files())
def test_sql_parses_as_one_trino_statement(path):
    sql = path.read_text()
    # cumulus-library splits a file on ";" without regard to comments or strings:
    # the only semicolon allowed is a single trailing one
    body = sql.rstrip().removesuffix(';')
    assert ';' not in body, f'{path.name}: ";" inside the statement (in a comment?) would split the build'
    comma = TRAILING_COMMA.search(strip_comments(body))
    assert comma is None, f'{path.name}: trailing comma before {comma.group(1)}'
    try:
        statements = sqlglot.parse(sql, read='trino', error_level=sqlglot.ErrorLevel.RAISE)
    except ParseError as e:
        pytest.fail(f'{path.name}: {e}')
    statements = [s for s in statements if s is not None]
    assert len(statements) == 1, f'{path.name}: expected one statement'
    assert not isinstance(statements[0], exp.Command), f'{path.name}: not recognised as SQL (keyword typo?)'
    if isinstance(statements[0], exp.Create):
        # sqlglot accepts 'CREATE TABLE x AS' with nothing after it, Athena does not
        assert statements[0].expression is not None, f'{path.name}: CREATE ... AS has no query body'
