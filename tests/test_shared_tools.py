"""Reusable helpers operate on another study's names, paths and schema."""
from datetime import date
from pathlib import Path

import duckdb
import pytest

from cumulus_library_pcx.tools import variable_tool
from cumulus_library_pcx.tools import qa_athena_tool
from tests.tools import synthetic_io
from cumulus_library_pcx.tools.fhir_reference import Aspect, get_column


def test_variable_discovery_preserves_upload_order_and_unique_names():
    files = [Path(name) for name in (
        'rx_drug.csv', 'dx_casedef.csv', 'README.csv', 'dx_cancer.v2.csv',
        'rx_drug.tsv', 'include_utilization.csv',
    )]
    uploads = variable_tool.list_uploads(files, exclude='casedef')
    assert uploads == [files[0], files[3], files[4]]
    assert variable_tool.list_variables(uploads) == ['dx_cancer', 'rx_drug']
    assert variable_tool.list_variables(uploads, 'dx') == ['dx_cancer']
    assert variable_tool.group_aspects(variable_tool.list_variables(uploads)) == {
        Aspect.dx: ['dx_cancer'], Aspect.rx: ['rx_drug'],
    }


@pytest.mark.parametrize('variable', ['dx_cancer', 'enc_class_inpatient'])
def test_cohort_sql_uses_supplied_names_and_matches_code_system(variable):
    column = get_column(variable)
    with duckdb.connect() as con:
        system_column = f', {column.system} VARCHAR' if column.system else ''
        con.execute(f'CREATE TABLE other_population ({column.code} VARCHAR{system_column})')
        con.execute('CREATE TABLE other_valueset (code VARCHAR, system VARCHAR)')
        con.execute("INSERT INTO other_valueset VALUES ('a', 'wanted')")
        if column.system:
            con.execute("INSERT INTO other_population VALUES ('a', 'wanted'), ('a', 'wrong'), ('b', 'wanted')")
        else:
            con.execute("INSERT INTO other_population VALUES ('a'), ('b')")
        con.execute(variable_tool.ctas_cohort('other_population', 'other_valueset', 'other_cohort', column))
        assert con.execute('SELECT COUNT(*) FROM other_cohort').fetchone()[0] == 1


def test_qa_discovery_and_summary_use_another_study(tmp_path):
    for name in ('other_warn_b.sql', 'other_warn_a.sql', 'other_warn_union.sql'):
        (tmp_path / name).touch()
    files = qa_athena_tool.list_sql(tmp_path, 'other_warn_*.sql', 'other_warn_union.sql')
    assert qa_athena_tool.list_tables(files) == ['other_warn_a', 'other_warn_b']
    assert len(qa_athena_tool.list_sql(tmp_path, '*.sql')) == 3
    # Preserve the old stage API's explicit empty-substring exclusion.
    assert qa_athena_tool.list_sql(tmp_path, '*.sql', '') == []
    with duckdb.connect() as con:
        con.execute('CREATE TABLE other_warn_a AS SELECT 1 WHERE FALSE')
        con.execute('CREATE TABLE other_warn_b AS SELECT 1')
        con.execute(qa_athena_tool.ctas_union_all('other_summary', qa_athena_tool.list_tables(files)))
        assert con.execute('SELECT * FROM other_summary ORDER BY test').fetchall() == [
            (0, 'other_warn_a'), (1, 'other_warn_b'),
        ]


def test_synthetic_io_build_order_types_and_quoted_path(tmp_path):
    folder = tmp_path / "another study's fixtures"
    folder.mkdir()
    schema = tmp_path / 'schema.sql'
    schema.write_text('CREATE TABLE people (subject_ref VARCHAR, seen DATE, flag BOOLEAN);')
    custom = tmp_path / 'custom'
    custom.mkdir()
    (custom / 'first.sql').write_text('CREATE TABLE first AS SELECT * FROM people;')
    (custom / 'second.sql').write_text('CREATE TABLE second AS SELECT * FROM first;')
    (tmp_path / 'stage.toml').write_text(
        '[[actions]]\nfiles = ["ignored.sql", "custom/first.sql", "custom/second.sql"]\n'
    )
    sql = synthetic_io.list_stage_sql(tmp_path, ['stage.toml'], sql_prefix='custom/')
    assert [path.name for path in sql] == ['first.sql', 'second.sql']
    rows = {'people': [{'subject_ref': 'p1', 'seen': date(2020, 1, 31), 'flag': True}]}
    with synthetic_io.build_database(rows, schema, sql, folder) as con:
        assert con.execute('SELECT * FROM second').fetchall() == [('p1', date(2020, 1, 31), True)]
        assert con.execute("SELECT date_diff('month', DATE '2020-01-31', DATE '2020-02-29')").fetchone() == (1,)


def test_synthetic_io_rejects_unknown_tables_and_columns(tmp_path):
    schema = tmp_path / 'schema.sql'
    schema.write_text('CREATE TABLE people (subject_ref VARCHAR);')
    with pytest.raises(KeyError, match='tables not in schema'):
        synthetic_io.build_database({'typo': []}, schema, [], tmp_path)
    with pytest.raises(KeyError, match='columns not in schema'):
        synthetic_io.build_database({'people': [{'typo': 1}]}, schema, [], tmp_path)


def test_export_distinguishes_null_and_empty_and_streams_all_rows(tmp_path):
    with duckdb.connect() as con:
        con.execute('CREATE TABLE result (id INTEGER, text VARCHAR, flag BOOLEAN)')
        con.execute("INSERT INTO result VALUES (2, '', FALSE), (1, NULL, TRUE), (3, 'a\"b', NULL)")
        output = tmp_path / 'result.csv'
        assert synthetic_io.export_athena_csv(con, 'result', output, order_by='id') == 3
        assert output.read_text() == (
            '"id","text","flag"\n"1",,"true"\n"2","","false"\n"3","a""b",\n'
        )
        con.execute('CREATE TABLE big AS SELECT range AS id FROM range(2001)')
        assert synthetic_io.export_athena_csv(con, 'big', output, order_by='id') == 2001
        assert len(output.read_text().splitlines()) == 2002
