"""Run the note-selection SQL on a few hand-made notes: which notes the survival_timeline task
reads (sql/custom/pcx__llm_document_task.sql), and the date each note gets
(sql/custom/pcx__llm_note_date.sql)."""
from datetime import date
import duckdb
import sqlglot
from sqlglot import exp
from cumulus_study_builder.tools import filetool


def projection(name: str) -> list[str]:
    """Column names of a generated wide table, read from its first SELECT."""
    tree = sqlglot.parse_one(filetool.path_sql_generated(f'{name}.sql').read_text(), read='trino')
    select = next(tree.find_all(exp.Select))
    return [column.alias_or_name for column in select.expressions]


def run(con, name: str):
    sql = filetool.path_sql_custom(f'{name}.sql').read_text()
    for statement in sqlglot.transpile(sql, read='trino', write='duckdb'):
        con.execute(statement)


def create(con, table: str, columns: list[str], rows: list[dict]):
    con.execute(f"CREATE TABLE {table} ({', '.join(f'{c} VARCHAR' for c in columns)})")
    for row in rows:
        con.execute(f"INSERT INTO {table} ({', '.join(row)}) VALUES ({', '.join('?' for _ in row)})",
                    list(row.values()))


# note_ref: (encounter_ref, document_type, survival_timeline_relevance)
NOTES = {
    'n_last':       ('E3', 'ONCOLOGY_NOTE', None),          # last visit
    'n_old':        ('E1', 'ONCOLOGY_NOTE', None),          # qualifies, earlier visit
    'n_implicit':   ('E1', 'OPERATIVE_NOTE', 'IMPLICIT'),   # qualifies, earlier visit
    'n_eol':        ('E2', 'END_OF_LIFE_DOCUMENT', None),   # death document, any visit
    'n_explicit':   ('E1', 'OPERATIVE_NOTE', 'EXPLICIT'),   # explicit relevance, any visit
    'n_unlinked':   (None, 'ONCOLOGY_NOTE', None),          # no encounter
    'n_outside':    ('E9', 'ONCOLOGY_NOTE', None),          # encounter outside the population
    'n_irrelevant': ('E3', 'OPERATIVE_NOTE', 'NONE_OF_THE_ABOVE'),
}


def test_survival_timeline_reads_last_visit_death_documents_and_unlinked_notes():
    con = duckdb.connect()
    subject = 'Patient/s1'
    create(con, 'pcx__llm_document_type_wide', projection('pcx__llm_document_type_wide'),
           [{'note_ref': note, 'subject_ref': subject, 'encounter_ref': enc, 'document_type': doc_type}
            for note, (enc, doc_type, _) in NOTES.items()])
    create(con, 'pcx__llm_document_topic_wide', projection('pcx__llm_document_topic_wide'),
           [{'note_ref': note, 'subject_ref': subject, 'encounter_ref': enc, 'survival_timeline_relevance': relevance}
            for note, (enc, _, relevance) in NOTES.items()])
    create(con, 'pcx__cohort_casedef', ['subject_ref', 'subtype', 'enc_period_start_day_min', 'age_at_casedef_min'],
           [{'subject_ref': subject, 'subtype': 'medulloblastoma'}])
    con.execute("CREATE TABLE pcx__cohort_study_population (encounter_ref VARCHAR, enc_period_start_day DATE)")
    con.execute("INSERT INTO pcx__cohort_study_population VALUES (?, ?), (?, ?), (?, ?)",
                ['E1', date(2020, 1, 1), 'E2', date(2021, 1, 1), 'E3', date(2022, 6, 1)])
    run(con, 'pcx__llm_document_task')
    selected = {r[0] for r in con.execute("SELECT note_ref FROM pcx__llm_document_task_survival_timeline").fetchall()}
    assert selected == {'n_last', 'n_eol', 'n_explicit', 'n_unlinked', 'n_outside'}


def test_every_selected_note_gets_a_date():
    con = duckdb.connect()
    create(con, 'pcx__sample_task', ['topic', 'subject_ref', 'note_ref'],
           [{'topic': topic, 'subject_ref': 'Patient/s1', 'note_ref': note} for topic, note in [
               ('casedef', 'DocumentReference/d_author'),
               ('diagnosis', 'DocumentReference/d_search'),         # Elasticsearch only
               ('diagnosis', 'DiagnosticReport/r_period'),
               ('casedef', 'DocumentReference/d_conflict'),
               ('diagnosis', 'DocumentReference/d_missing')]])     # no core row
    con.execute('CREATE TABLE core__documentreference (documentreference_ref VARCHAR, author_day DATE, "date" TIMESTAMP)')
    con.execute("INSERT INTO core__documentreference VALUES "
                "('DocumentReference/d_author', DATE '2020-01-05', TIMESTAMP '2020-01-09 10:00:00'), "
                "('DocumentReference/d_search', NULL, TIMESTAMP '2021-03-04 08:30:00'), "
                "('DocumentReference/d_conflict', DATE '2020-02-01', NULL), "
                "('DocumentReference/d_conflict', DATE '2020-02-02', NULL)")
    con.execute('CREATE TABLE core__diagnosticreport (diagnosticreport_ref VARCHAR, '
                'effectivedatetime_day DATE, effectiveperiod_start_day DATE)')
    con.execute("INSERT INTO core__diagnosticreport VALUES ('DiagnosticReport/r_period', NULL, DATE '2022-07-01')")
    run(con, 'pcx__llm_note_date')
    rows = {r[0]: r[1:] for r in con.execute(
        "SELECT note_ref, note_date, note_date_conflict_bool FROM pcx__llm_note_date").fetchall()}
    assert rows == {
        'DocumentReference/d_author':   (date(2020, 1, 5), False),   # author day wins over date
        'DocumentReference/d_search':   (date(2021, 3, 4), False),   # search-only note, date fallback
        'DiagnosticReport/r_period':    (date(2022, 7, 1), False),   # effectivePeriod start fallback
        'DocumentReference/d_conflict': (None, True),
        'DocumentReference/d_missing':  (None, False),
    }
