"""Run sql/custom/client_diagnosis.sql on the seeded fixtures with its own molecular reports, and
check which report sets the subject's molecular group and method."""
from datetime import date
import sqlglot
from cumulus_study_builder.tools import filetool
from tests import sqltest

OLD, NEW = '2026-09-01T00:00:00', '2026-10-01T00:00:00'


def test_molecular_group_comes_from_one_real_report():
    con = sqltest.connect()
    sqltest.run_custom(con)
    con.execute("DELETE FROM pcx__llm_molecular_report")
    # (subject, note, note date, report index, group, methods, extraction output)
    reports = [
        # p1: methylation Group 3, then a LATER indeterminate result read by IHC.
        # The uncertain result must not replace Group 3, nor lend it its method.
        ('Patient/p1', 'note-mol-a', date(2020, 2, 1), 1, 'GROUP_3', 'DNA_METHYLATION', OLD),
        ('Patient/p1', 'note-mol-b', date(2021, 6, 1), 1, 'INDETERMINATE', 'IMMUNOHISTOCHEMISTRY', OLD),
        # p8: two reports in one note: the last report in the note wins, with its own method
        ('Patient/p8', 'note-mol-c', date(2020, 7, 1), 1, 'GROUP_4', 'CLINICAL_SUMMARY', OLD),
        ('Patient/p8', 'note-mol-c', date(2020, 7, 1), 2, 'SHH', 'SEQUENCING', OLD),
        # p2: no real group at all, so the uncertain value is reported, with no method
        ('Patient/p2', 'note-mol-d', date(2015, 1, 10), 1, 'NOT_SUBGROUPED', '', OLD),
        # p3: two outputs for the SAME note and report index. The real group wins over the
        # newer uncertain output, and the subject still has one row.
        ('Patient/p3', 'note-mol-e', date(2019, 3, 1), 1, 'GROUP_3', 'DNA_METHYLATION', OLD),
        ('Patient/p3', 'note-mol-e', date(2019, 3, 1), 1, 'INDETERMINATE', 'IMMUNOHISTOCHEMISTRY', NEW),
        # p6: two real outputs for the same note and index. The newer output wins, with its method.
        ('Patient/p6', 'note-mol-f', date(2021, 1, 5), 1, 'SHH', 'IMMUNOHISTOCHEMISTRY', OLD),
        ('Patient/p6', 'note-mol-f', date(2021, 1, 5), 1, 'GROUP_4', 'DNA_METHYLATION', NEW),
    ]
    for subject, note, day, index, group, methods, generated_on in reports:
        con.execute("INSERT INTO pcx__llm_molecular_report "
                    "(subject_ref, note_ref, report_index, molecular_group, methods, generated_on, system_fingerprint) "
                    "VALUES (?, ?, ?, ?, ?, ?, 'fp')", [subject, note, index, group, methods, generated_on])
    for subject, note, day in {(r[0], r[1], r[2]) for r in reports}:
        con.execute("INSERT INTO pcx__llm_note_date VALUES (?, ?, ?)", [subject, note, day])
    sql = filetool.path_sql_custom('client_diagnosis.sql').read_text()
    for statement in sqlglot.transpile(sql, read='trino', write='duckdb'):
        con.execute(statement)
    result = con.execute(
        "SELECT subject_ref, molecular_group_ever, molecular_group_method, molecular_group_distinct_count "
        "FROM pcx__client_diagnosis").fetchall()
    rows = {r[0]: r[1:] for r in result}
    assert len(rows) == len(result)
    assert rows['Patient/p1'] == ('GROUP_3', 'DNA_METHYLATION', 1)
    assert rows['Patient/p8'] == ('SHH', 'SEQUENCING', 2)
    assert rows['Patient/p2'] == ('NOT_SUBGROUPED', None, 0)
    assert rows['Patient/p3'] == ('GROUP_3', 'DNA_METHYLATION', 1)
    assert rows['Patient/p6'] == ('GROUP_4', 'DNA_METHYLATION', 2)
