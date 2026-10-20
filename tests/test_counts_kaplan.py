"""Kaplan-Meier count cubes: the source SQL and counts workflows, executed in DuckDB."""
import datetime

import duckdb
from cumulus_library import CountsBuilder, StudyManifest

from tests.conftest import ROOT

GENERATED = ROOT / 'cumulus_library_pcx/sql/generated'
SOURCE = ROOT / 'cumulus_library_pcx/sql/custom/pcx__kaplan_subject.sql'

# Headers of the PCX-30 2026-10-02 OS and EFS _cube.csv files, in order, without site:
# the aggregator adds site when it combines each site's export
OS_COLS = ['cnt', 'diagnosis', 'overall_survival_years', 'vital_status', 'age_at_diagnosis_under_36mo',
           'ever_methotrexate', 'radiation', 'subtype']
EFS_COLS = ['cnt', 'diagnosis', 'event_free_survival_years', 'efs_status', 'age_at_diagnosis_under_36mo',
            'ever_methotrexate', 'radiation', 'subtype', 'initial_treatment_order']

T0 = datetime.date(2015, 1, 1)


def day(n: int) -> datetime.date:
    return T0 + datetime.timedelta(days=n)


def outcome(i, t0=T0, os_event=False, os_days=400, efs_event=False, efs_days=400, under_36=False,
            methotrexate=None, chemo=None, radiation=None, sequence=None):
    return (f'Patient/{i}', t0, os_event, os_days, efs_event, efs_days, under_36,
            methotrexate, chemo, radiation, sequence)


def load(con, outcome_rows: list, molecular_rows: list):
    con.execute('CREATE OR REPLACE TABLE pcx__outcome (subject_ref VARCHAR, t0_day DATE, os_event_bool BOOLEAN, '
                'os_days BIGINT, efs_event_bool BOOLEAN, efs_days BIGINT, '
                'age_under_36_months_at_definitive_surgery BOOLEAN, methotrexate_first_day DATE, '
                'chemo_first_day DATE, radiation_first_day DATE, initial_therapy_sequence VARCHAR)')
    con.execute('CREATE OR REPLACE TABLE pcx__client_diagnosis (subject_ref VARCHAR, molecular_group_ever VARCHAR)')
    con.executemany('INSERT INTO pcx__outcome VALUES (' + ', '.join(['?'] * 11) + ')', outcome_rows)
    if molecular_rows:
        con.executemany('INSERT INTO pcx__client_diagnosis VALUES (?, ?)', molecular_rows)
    con.execute('DROP TABLE IF EXISTS pcx__kaplan_subject')
    con.execute(SOURCE.read_text())


def count_sql(workflow: str, table: str) -> str:
    manifest = StudyManifest(ROOT / 'cumulus_library_pcx')
    builder = CountsBuilder(manifest, toml_config_path=GENERATED / workflow)
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
            outcome(8, efs_event=True, under_36=True, methotrexate=day(10), chemo=day(10), radiation=day(40),
                    sequence='CHEMOTHERAPY_BEFORE_RADIATION'),
            outcome(9, chemo=day(900)),
            outcome(10)]
    molecular = [('Patient/0', 'WNT'), ('Patient/1', 'GROUP_3'), ('Patient/2', 'NON_WNT_NON_SHH'),
                 ('Patient/3', 'NOT_SUBGROUPED'), ('Patient/4', 'INDETERMINATE')]
    load(con, rows, molecular)
    df = con.execute('SELECT * FROM pcx__kaplan_subject ORDER BY CAST(SUBSTR(subject_ref, 9) AS INTEGER)').fetchdf()
    s = df.to_dict('records')

    # 3652 days is 9.9986 years, 3653 is 10.0014
    assert [r['overall_survival_years'] for r in s[:8]] == \
        ['0', '0', '1', '9', '>=10', 'Not Applicable', 'Not Reported', 'Not Reported']
    assert [r['subtype'] for r in s[:6]] == ['WNT', 'Group 3', 'non-WNT/non-SHH', 'NOS/NEC', 'NOS/NEC', 'NOS/NEC']
    assert (s[6]['vital_status'], s[0]['vital_status']) == ('deceased', 'alive')
    assert (s[8]['efs_status'], s[0]['efs_status']) == ('event', 'event-free')
    assert [s[i]['age_at_diagnosis_under_36mo'] for i in (8, 0, 5)] == ['Yes', 'No', 'Not Reported']
    # no exposure evidence is unknown, never No
    assert (s[8]['ever_methotrexate'], s[8]['radiation']) == ('Yes', 'Yes')
    assert (s[0]['ever_methotrexate'], s[0]['radiation']) == ('Not Reported', 'Not Reported')
    assert [s[i]['initial_treatment_order'] for i in (8, 9, 10, 5)] == \
        ['chemo_before_radiation', 'no_initial_radiation_or_chemo', 'Not Reported', 'Not Applicable']
    assert set(df.diagnosis) == {'Medulloblastoma'}
    assert df.drop(columns='subject_ref').isna().sum().sum() == 0


def test_columns_match_pcx30_and_floor_of_one():
    con = duckdb.connect()
    # 12 alive at 0 years, 3 deceased at 1 year
    rows = [outcome(i, os_days=100) for i in range(12)] + [outcome(100 + i, os_event=True, os_days=400) for i in range(3)]
    load(con, rows, [])

    os_cube = cube(con, 'pcx__counts_kaplan.workflow', 'pcx__cube_kaplan_os')
    efs_cube = cube(con, 'pcx__counts_kaplan.workflow', 'pcx__cube_kaplan_efs')
    assert list(os_cube.columns) == OS_COLS
    assert list(efs_cube.columns) == EFS_COLS

    dims = OS_COLS[1:]
    grand = os_cube[os_cube[dims].isna().all(axis=1)]
    assert grand.cnt.tolist() == [15]
    others = [c for c in dims if c != 'vital_status']
    deceased = os_cube[(os_cube.vital_status == 'deceased') & os_cube[others].isna().all(axis=1)]
    # the approved floor of 1 keeps the 3 deaths in the exported cube
    assert deceased.cnt.tolist() == [3]
