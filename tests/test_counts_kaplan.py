"""Kaplan-Meier count cubes: the source SQL and counts workflow, executed in DuckDB."""
import datetime

import duckdb
from cumulus_library import CountsBuilder, StudyManifest

from tests.conftest import ROOT

SOURCE = ROOT / 'cumulus_library_pcx/sql/custom/pcx__kaplan_subject.sql'
DEMO = ROOT / 'cumulus_library_pcx/sql/custom/pcx__kaplan_subject_demo.sql'

# Based on the headers of the PCX-30 2026-10-02 OS and EFS _cube.csv files, in order, without site:
# the aggregator adds site when it combines each site's export. Survival is in months instead of
# years, the two exposure strata are initial therapy (had_initial_*) instead of PCX-30's
# ever_methotrexate and radiation, and protocol_name and documented_trial_arm are added at the end.
OS_COLS = ['cnt', 'diagnosis', 'overall_survival_months', 'vital_status', 'age_at_diagnosis_under_36mo',
           'had_initial_methotrexate', 'had_initial_radiation', 'subtype', 'protocol_name', 'documented_trial_arm']
EFS_COLS = ['cnt', 'diagnosis', 'event_free_survival_months', 'efs_status', 'age_at_diagnosis_under_36mo',
            'had_initial_methotrexate', 'had_initial_radiation', 'subtype', 'initial_treatment_order',
            'protocol_name', 'documented_trial_arm']

T0 = datetime.date(2015, 1, 1)


def outcome(i, t0=T0, os_event=False, os_days=400, efs_event=False, efs_days=400, under_36=False,
            methotrexate=None, radiation=None, sequence=None):
    return (f'Patient/{i}', t0, os_event, os_days, efs_event, efs_days, under_36, methotrexate, radiation, sequence)


def load(con, outcome_rows: list, molecular_rows: list, regimen_rows: list = (), note_date_rows: list = ()):
    """regimen_rows are (subject_ref, protocol_name, documented_trial_arm[, regimen_start_day[, note_ref]]),
    note_date_rows are (subject_ref, note_ref, note_date)."""
    # Athena ARRAY_JOIN, as in tests/sqltest.py
    con.execute("CREATE OR REPLACE MACRO array_join(a, s) AS list_aggregate(a, 'string_agg', s)")
    con.execute('CREATE OR REPLACE TABLE pcx__outcome (subject_ref VARCHAR, t0_day DATE, os_event_bool BOOLEAN, '
                'os_days BIGINT, efs_event_bool BOOLEAN, efs_days BIGINT, '
                'age_under_36_months_at_definitive_surgery BOOLEAN, had_initial_methotrexate_bool BOOLEAN, '
                'had_initial_radiation_bool BOOLEAN, initial_therapy_sequence VARCHAR)')
    con.execute('CREATE OR REPLACE TABLE pcx__client_diagnosis (subject_ref VARCHAR, molecular_group_ever VARCHAR, '
                'disease_subtype_ever VARCHAR)')
    con.executemany('INSERT INTO pcx__outcome VALUES (' + ', '.join(['?'] * 10) + ')', outcome_rows)
    if molecular_rows:
        con.executemany('INSERT INTO pcx__client_diagnosis VALUES (?, ?, ?)', molecular_rows)
    con.execute('CREATE OR REPLACE TABLE pcx__llm_systemic_therapy_regimen (subject_ref VARCHAR, '
                'protocol_name VARCHAR, documented_trial_arm VARCHAR, regimen_start_day DATE, note_ref VARCHAR)')
    padded = list()
    for row in regimen_rows:
        padded.append(tuple(row) + (None,) * (5 - len(row)))
    if padded:
        con.executemany('INSERT INTO pcx__llm_systemic_therapy_regimen VALUES (?, ?, ?, ?, ?)', padded)
    con.execute('CREATE OR REPLACE TABLE pcx__llm_note_date (subject_ref VARCHAR, note_ref VARCHAR, note_date DATE)')
    if note_date_rows:
        con.executemany('INSERT INTO pcx__llm_note_date VALUES (?, ?, ?)', note_date_rows)
    con.execute('DROP TABLE IF EXISTS pcx__kaplan_subject')
    con.execute(SOURCE.read_text())


def count_sql(workflow: str, table: str) -> str:
    manifest = StudyManifest(ROOT / 'cumulus_library_pcx')
    builder = CountsBuilder(manifest, toml_config_path=ROOT / 'cumulus_library_pcx' / workflow)
    builder.prepare_queries(config=None, manifest=manifest)
    for sql in builder.queries:
        if sql.startswith(f'CREATE TABLE {table} '):
            return sql
    raise KeyError(table)


def cube(con, workflow: str, table: str):
    con.execute(f'DROP TABLE IF EXISTS {table}')
    con.execute(count_sql(workflow, table))
    return con.execute(f'SELECT * FROM {table}').fetchdf()


def test_labels():
    con = duckdb.connect()
    rows = [outcome(0, os_days=364), outcome(1, os_days=365), outcome(2, os_days=366),
            outcome(3, os_days=3652), outcome(4, os_days=3653),
            outcome(5, t0=None, os_days=None, efs_days=None, under_36=None),
            outcome(6, os_event=True, os_days=None), outcome(7, os_days=-3),
            outcome(8, efs_event=True, under_36=True, methotrexate=True, radiation=True,
                    sequence='CHEMOTHERAPY_BEFORE_RADIATION'),
            outcome(9, sequence='NO_INITIAL_THERAPY'),
            outcome(10),
            outcome(11, efs_event=True, efs_days=None),
            outcome(12, efs_event=True, methotrexate=False, radiation=False, sequence='CHEMOTHERAPY_ONLY')]
    molecular = [('Patient/0', 'WNT', 'MEDULLOBLASTOMA'), ('Patient/1', 'GROUP_3', 'MEDULLOBLASTOMA'),
                 ('Patient/2', 'NON_WNT_NON_SHH', 'MEDULLOBLASTOMA'), ('Patient/3', 'NOT_SUBGROUPED', 'ATRT'),
                 ('Patient/4', 'INDETERMINATE', None)]
    nota = 'NONE_OF_THE_ABOVE'
    regimens = [('Patient/0', 'ACNS0334', 'REGIMEN_B'),
                ('Patient/1', 'ACNS0334', nota), ('Patient/1', 'ACNS0334', 'REGIMEN_A'),
                ('Patient/2', 'ACNS0334', nota),
                ('Patient/3', 'HEAD_START', nota), ('Patient/3', 'ACNS0334', 'REGIMEN_A'),
                ('Patient/3', 'ACNS0334', 'REGIMEN_B'),
                ('Patient/4', nota, 'REGIMEN_A'),
                ('Patient/5', 'CCG99703', 'REGIMEN_B')]
    load(con, rows, molecular, regimens)
    df = con.execute('SELECT * FROM pcx__kaplan_subject ORDER BY CAST(SUBSTR(subject_ref, 9) AS INTEGER)').fetchdf()
    s = df.to_dict('records')

    # 3652 days is 9.9986 years, 3653 is 10.0014
    assert [r['overall_survival_years'] for r in s[:8]] == \
        ['0', '0', '1', '9', '>=10', 'Not Applicable', 'Not Reported', 'Not Reported']
    # months are FLOOR(days / 30.4375) with no cap: 364 days is 11.96 months, 366 is 12.02
    assert [r['overall_survival_months'] for r in s[:8]] == \
        ['11', '11', '12', '119', '120', 'Not Applicable', 'Not Reported', 'Not Reported']
    assert [s[i]['event_free_survival_months'] for i in (0, 5, 11)] == ['13', 'Not Applicable', 'Not Reported']
    assert [r['subtype'] for r in s[:6]] == ['WNT', 'Group 3', 'non-WNT/non-SHH', 'NOS/NEC', 'NOS/NEC', 'NOS/NEC']
    assert (s[6]['vital_status'], s[0]['vital_status']) == ('deceased', 'alive')
    assert (s[8]['efs_status'], s[0]['efs_status']) == ('event', 'event-free')
    assert [s[i]['age_at_diagnosis_under_36mo'] for i in (8, 0, 5)] == ['Yes', 'No', 'Not Reported']
    # initial-therapy strata: Yes, a documented No, unknown, and no t0
    strata = [(s[i]['had_initial_methotrexate'], s[i]['had_initial_radiation']) for i in (8, 12, 0, 5)]
    assert strata == [('Yes', 'Yes'), ('No', 'No'), ('Not Reported', 'Not Reported'),
                      ('Not Applicable', 'Not Applicable')]
    assert [s[i]['initial_treatment_order'] for i in (8, 12, 9, 10, 5)] == \
        ['chemo_before_radiation', 'chemo_only_no_initial_radiation', 'no_initial_radiation_or_chemo',
         'Not Reported', 'Not Applicable']
    # an event without a usable date counts as an event with no duration, and its exposures are unordered
    assert (s[11]['efs_status'], s[11]['event_free_survival_years'], s[11]['initial_treatment_order']) == \
        ('event', 'Not Reported', 'Not Reported')
    # diagnosis is the latest documented subtype, not an exclusion: ATRT stays, none documented is Not Reported
    assert [s[i]['diagnosis'] for i in (0, 3, 4, 6)] == ['MEDULLOBLASTOMA', 'ATRT', 'Not Reported', 'Not Reported']
    # protocol: every coded protocol, sorted and comma-joined, or Not Reported (NONE_OF_THE_ABOVE is not a protocol).
    # arm: ACNS0334 regimens only, so the CCG99703 arm of Patient/5 is ignored.
    assert [(s[i]['protocol_name'], s[i]['documented_trial_arm']) for i in range(7)] == \
        [('ACNS0334', 'REGIMEN_B'), ('ACNS0334', 'REGIMEN_A'), ('ACNS0334', 'Not Reported'),
         ('ACNS0334,HEAD_START', 'Conflicting'), ('Not Reported', 'Not Applicable'), ('CCG99703', 'Not Applicable'),
         ('Not Reported', 'Not Applicable')]
    assert df.drop(columns='subject_ref').isna().sum().sum() == 0


def test_protocol_order_by_date():
    con = duckdb.connect()
    day = datetime.date
    regimens = [
        # alphabetical and date order differ, and the earliest of a protocol's rows counts
        ('Patient/0', 'ACNS0334', 'REGIMEN_A', day(2016, 1, 1)), ('Patient/0', 'ACNS0334', 'REGIMEN_A', day(2018, 1, 1)),
        ('Patient/0', 'HEAD_START', 'NONE_OF_THE_ABOVE', day(2015, 3, 1)),
        # no start date: the note date stands in
        ('Patient/1', 'ACNS0334', 'NONE_OF_THE_ABOVE', None, 'DocumentReference/n1'),
        ('Patient/1', 'CCG99703', 'NONE_OF_THE_ABOVE', day(2016, 6, 1)),
        # no start date and no note date: last
        ('Patient/2', 'ACNS0334', 'NONE_OF_THE_ABOVE'), ('Patient/2', 'SJYC07', 'NONE_OF_THE_ABOVE', day(2015, 5, 1))]
    notes = [('Patient/1', 'DocumentReference/n1', day(2017, 1, 1))]
    load(con, [outcome(i) for i in range(4)], [], regimens, notes)
    rows = con.execute('SELECT subject_ref, protocol_name, protocol_name_by_date FROM pcx__kaplan_subject '
                       'ORDER BY subject_ref').fetchall()
    assert rows == [('Patient/0', 'ACNS0334,HEAD_START', 'HEAD_START,ACNS0334'),
                    ('Patient/1', 'ACNS0334,CCG99703', 'CCG99703,ACNS0334'),
                    ('Patient/2', 'ACNS0334,SJYC07', 'SJYC07,ACNS0334'),
                    ('Patient/3', 'Not Reported', 'Not Reported')]


def test_demo_cohort():
    con = duckdb.connect()
    rows = [outcome(0), outcome(1, methotrexate=True), outcome(2), outcome(3), outcome(4), outcome(5, methotrexate=False),
            outcome(6, t0=None, os_days=None, efs_days=None), outcome(7, efs_event=True, efs_days=None),
            outcome(8, os_event=True, os_days=None), outcome(9), outcome(10), outcome(11), outcome(12)]
    molecular = [('Patient/0', 'GROUP_3', 'MEDULLOBLASTOMA'), ('Patient/1', 'GROUP_4', 'MEDULLOBLASTOMA'),
                 ('Patient/2', 'NON_WNT_NON_SHH', 'MEDULLOBLASTOMA'), ('Patient/3', 'SHH', 'MEDULLOBLASTOMA'),
                 ('Patient/4', 'GROUP_3', 'ATRT'), ('Patient/5', 'GROUP_3', 'MEDULLOBLASTOMA'),
                 ('Patient/6', 'GROUP_3', 'MEDULLOBLASTOMA'), ('Patient/7', 'GROUP_3', 'MEDULLOBLASTOMA'),
                 ('Patient/8', 'GROUP_3', 'MEDULLOBLASTOMA'), ('Patient/9', 'GROUP_3', 'MEDULLOBLASTOMA'),
                 ('Patient/10', 'GROUP_4', 'MEDULLOBLASTOMA'), ('Patient/11', 'GROUP_4', 'MEDULLOBLASTOMA'),
                 ('Patient/12', 'GROUP_4', 'MEDULLOBLASTOMA')]
    nota = 'NONE_OF_THE_ABOVE'
    regimens = [('Patient/0', 'ACNS0334', 'REGIMEN_A'), ('Patient/2', 'ACNS0334', nota),
                ('Patient/3', 'ACNS0334', 'REGIMEN_B'), ('Patient/4', 'ACNS0334', 'REGIMEN_B'),
                ('Patient/6', 'ACNS0334', 'REGIMEN_B'), ('Patient/7', 'ACNS0334', 'REGIMEN_B'),
                ('Patient/8', 'ACNS0334', 'REGIMEN_B'),
                ('Patient/9', 'HEAD_START', nota), ('Patient/9', 'ACNS0334', 'REGIMEN_B'),
                ('Patient/10', 'CCG99703', nota), ('Patient/11', 'PBTC_026', nota), ('Patient/12', 'HEAD_START', nota)]
    load(con, rows, molecular, regimens)
    con.execute(DEMO.read_text())
    demo = con.execute('SELECT subject_ref, protocol_name, os_months, efs_months FROM pcx__kaplan_subject_demo '
                       'ORDER BY CAST(SUBSTR(subject_ref, 9) AS INTEGER)').fetchall()
    # kept: ACNS0334 with an arm, initial methotrexate without a listed protocol, ACNS0334 without an arm,
    # ACNS0334 beside another protocol, CCG99703 and PBTC_026. Left out: SHH, ATRT, neither
    # treatment, no t0, an undated EFS event, an undated death, and Head Start (not a listed protocol).
    assert demo == [('Patient/0', 'ACNS0334', 13, 13), ('Patient/1', 'Not Reported', 13, 13),
                    ('Patient/2', 'ACNS0334', 13, 13), ('Patient/9', 'ACNS0334,HEAD_START', 13, 13),
                    ('Patient/10', 'CCG99703', 13, 13), ('Patient/11', 'PBTC_026', 13, 13)]


def test_cube_columns_and_floor_of_one():
    con = duckdb.connect()
    # 12 alive at 3 months, 3 deceased at 13 months
    rows = [outcome(i, os_days=100) for i in range(12)] + [outcome(100 + i, os_event=True, os_days=400) for i in range(3)]
    load(con, rows, [])

    os_cube = cube(con, 'counts_kaplan.workflow', 'pcx__cube_kaplan_os')
    efs_cube = cube(con, 'counts_kaplan.workflow', 'pcx__cube_kaplan_efs')
    assert list(os_cube.columns) == OS_COLS
    assert list(efs_cube.columns) == EFS_COLS

    dims = OS_COLS[1:]
    grand = os_cube[os_cube[dims].isna().all(axis=1)]
    assert grand.cnt.tolist() == [15]
    others = [c for c in dims if c != 'vital_status']
    deceased = os_cube[(os_cube.vital_status == 'deceased') & os_cube[others].isna().all(axis=1)]
    # the approved floor of 1 keeps the 3 deaths in the exported cube
    assert deceased.cnt.tolist() == [3]
