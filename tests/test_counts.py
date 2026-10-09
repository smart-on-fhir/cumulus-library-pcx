"""Count suppression on synthetic rows: the rendered counts workflow, executed in DuckDB."""
import duckdb
from cumulus_library import CountsBuilder, StudyManifest

from tests.conftest import ROOT

# pcx__cohort_study_population_enc columns, then the encounter cube's breakdown (age_group, not age_at_visit)
ENC_COLS = ['age_at_visit', 'age_group', 'enc_class_display', 'enc_period_start_year',
            'enc_servicetype_display', 'enc_type_display']
ENC_CUBE_COLS = ['age_group', 'enc_class_display', 'enc_period_start_year',
                 'enc_servicetype_display', 'enc_type_display']


def count_sql(table: str) -> str:
    manifest = StudyManifest(ROOT / 'cumulus_library_pcx')
    builder = CountsBuilder(manifest, toml_config_path=ROOT / 'cumulus_library_pcx/sql/generated/pcx__counts.workflow')
    builder.prepare_queries(config=None, manifest=manifest)
    for sql in builder.queries:
        if sql.startswith(f'CREATE TABLE {table} '):
            return sql
    raise KeyError(table)


def encounters(con, patients: int, per_patient: int):
    rows = list()
    for p in range(patients):
        for e in range(per_patient):
            rows.append((f'Patient/{p}', f'Encounter/{p}-{e}', f'Encounter/{p}-{e}',
                         '3', 'Childhood', 'AMB', '2020', 'onc', 'visit'))
    con.execute('CREATE OR REPLACE TABLE pcx__cohort_study_population_enc (subject_ref VARCHAR, encounter_ref VARCHAR, '
                'encounter_ref_link VARCHAR, ' + ', '.join(c + ' VARCHAR' for c in ENC_COLS) + ')')
    if rows:
        con.executemany('INSERT INTO pcx__cohort_study_population_enc VALUES (' + ', '.join(['?'] * 9) + ')', rows)


def grand_total(con, table: str, dims: list[str]):
    where = ' AND '.join(f'{d} IS NULL' for d in dims)
    return con.execute(f'SELECT cnt FROM {table} WHERE {where}').fetchall()


def test_encounter_cube_suppresses_on_patients_not_encounters():
    con = duckdb.connect()
    sql = count_sql('pcx__cube_encounter_study_population_enc')
    table = 'pcx__cube_encounter_study_population_enc'

    encounters(con, patients=1, per_patient=12)     # 12 encounters, one patient
    con.execute(sql)
    assert con.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0] == 0

    con.execute(f'DROP TABLE {table}')
    encounters(con, patients=9, per_patient=5)      # 45 encounters, 9 patients
    con.execute(sql)
    assert con.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0] == 0

    con.execute(f'DROP TABLE {table}')
    encounters(con, patients=10, per_patient=2)     # at the floor: cnt is encounters
    con.execute(sql)
    assert grand_total(con, table, ENC_CUBE_COLS) == [(20,)]


def test_variable_union_counts_only_evidence_with_a_linked_encounter():
    con = duckdb.connect()
    encounters(con, patients=10, per_patient=1)
    con.execute('CREATE TABLE pcx__cohort_variable_union (variable VARCHAR, code VARCHAR, display VARCHAR, '
                'system VARCHAR, subject_ref VARCHAR, encounter_ref_link VARCHAR, resource_ref VARCHAR)')
    rows = list()
    for p in range(10):
        rows.append(('dx_medulloblastoma', 'C71.6', 'MB', 'icd10', f'Patient/{p}', f'Encounter/{p}-0', f'Condition/{p}'))
    for p in range(10, 15):   # evidence without a study-population encounter is not counted
        rows.append(('dx_medulloblastoma', 'C71.6', 'MB', 'icd10', f'Patient/{p}', None, f'Condition/{p}'))
    con.executemany('INSERT INTO pcx__cohort_variable_union VALUES (?, ?, ?, ?, ?, ?, ?)', rows)
    con.execute(count_sql('pcx__cube_patient_variable_union'))
    dims = ['code', 'display', 'system', 'variable', 'age_group']
    assert grand_total(con, 'pcx__cube_patient_variable_union', dims) == [(10,)]
