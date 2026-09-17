"""Exercise every tests/athena/pcx__warn_*.sql table on the synthetic tables in tests/data.

Each synthetic subject is seeded with one or more anomalies (see tests/data/schema.sql), and
each warn table is asserted against the exact set of (warn_check, subject_ref) pairs it must
produce. A warn table that starts firing on a clean subject, or stops firing on a seeded one,
fails here.
"""
import pathlib
import pytest
from tests import sqltest

EXPECTED = {
    "pcx__warn_eligible_t0_missing": {("t0_missing_llm_medulloblastoma", "Patient/p3")},
    "pcx__warn_eligible_t0_anchor_disagree": {("t0_anchor_casedef_earlier", "Patient/p1")},
    "pcx__warn_eligible_t0_after_condition_date": {("t0_after_condition_date", "Patient/p1")},
    "pcx__warn_eligible_dx_date_disagree_fhir_before_llm": {("dx_date_fhir_before_llm", "Patient/p8")},
    "pcx__warn_eligible_dx_date_disagree_llm_before_fhir": {("dx_date_llm_before_fhir", "Patient/p6")},
    "pcx__warn_eligible_age_near_36_month_boundary": {("age_at_t0_near_36_months", "Patient/p6"),
                                                      ("age_at_definitive_surgery_near_36_months", "Patient/p6")},
    "pcx__warn_eligible_age_disagree": {("age_at_diagnosis_disagree", "Patient/p6"), ("age_at_surgery_disagree", "Patient/p6")},
    "pcx__warn_eligible_dx_subtype_conflict": {("subtype_conflict_llm", "Patient/p6")},
    "pcx__warn_eligible_surgery_timing": {("surgery_llm_vs_structured_disagree", "Patient/p6"),
                                          ("surgery_long_before_t0", "Patient/p7"),
                                          ("surgery_long_after_t0", "Patient/p8")},
    "pcx__warn_eligible_surgery_evidence": {("surgery_missing", "Patient/p5"),
                                            ("surgery_multiple_tier1", "Patient/p2"),
                                            ("surgery_undated_tier1", "Patient/p8"),
                                            ("surgery_llm_without_role", "Patient/p2"),
                                            ("surgery_llm_without_role", "Patient/p3")},
    "pcx__warn_eligible_therapy_precedes_t0": {("chemo_precedes_t0", "Patient/p2")},
    "pcx__warn_eligible_rx_llm_agent_unrecognized": {("rx_llm_agent_unrecognized", "Patient/p1")},
    "pcx__warn_eligible_radiation_evidence_conflict": {("radiation_not_received_vs_evidence", "Patient/p6"),
                                                       ("radiation_history_code_ignored", "Patient/p6")},
    "pcx__warn_eligible_subject_missing_patient": {("subject_missing_core_patient", "Patient/p4"),
                                                   ("subject_missing_birthdate", "Patient/p5")},
    "pcx__warn_outcome_vital_status_conflict": {("death_day_disagree", "Patient/p2"), ("alive_after_death", "Patient/p2"),
                                                ("deceased_without_death_day", "Patient/p6"),
                                                ("death_before_t0", "Patient/p7"), ("alive_after_death", "Patient/p7")},
    "pcx__warn_outcome_first_event_timing": {("event_after_death", "Patient/p2"), ("undated_events_only", "Patient/p6"),
                                             ("event_before_t0", "Patient/p7"), ("first_event_multiple_types", "Patient/p8")},
    "pcx__warn_outcome_exposure_order_only": {("chemo_order_only", "Patient/p2"), ("radiation_code_only", "Patient/p2"),
                                              ("methotrexate_order_only", "Patient/p6"),
                                              ("radiation_code_only", "Patient/p6"), ("radiation_code_only", "Patient/p8")},
    "pcx__warn_outcome_exposure_after_first_event": {("methotrexate_after_first_event", "Patient/p8"),
                                                     ("radiation_after_first_event", "Patient/p8")},
    "pcx__warn_outcome_survival_days": {("os_days_null_deceased", "Patient/p6"), ("os_days_negative", "Patient/p7"),
                                        ("os_days_zero", "Patient/p8")},
    "pcx__warn_llm_date_coarse": {("llm_date_coarse_month", "Patient/p1"), ("llm_date_coarse_year", "Patient/p6")},
    "pcx__warn_llm_date_after_note": {("llm_date_after_note", "Patient/p7")},
    "pcx__warn_study_period_null_end": {("null_end_in_window", "Patient/p1"), ("null_end_history", "Patient/p6")},
}


QA_EXPECTED = {
    "pcx__qa_study_period_bounds": set(),
    "pcx__qa_study_population_utilization": {("periods_below_min", "Patient/p3")},
}


@pytest.fixture(scope="module")
def con():
    con = sqltest.connect()
    sqltest.run_custom(con)
    sqltest.run_athena(con, "pcx__warn_*.sql")
    sqltest.run_athena(con, "pcx__qa_*.sql")
    return con


def test_every_warn_table_has_expectations():
    tables = {f.stem for f in sqltest.list_athena("pcx__warn_*.sql")} - {"pcx__warn_union"}
    assert tables == set(EXPECTED)


@pytest.mark.parametrize("table", sorted(EXPECTED))
def test_warn_table_fires_only_on_seeded_subjects(con, table):
    rows = con.execute(f"SELECT warn_check, subject_ref, detail FROM {table}").fetchall()
    assert {(check, subject) for check, subject, _ in rows} == EXPECTED[table]
    assert all(check is not None and detail for check, _, detail in rows)
    columns = [c[0] for c in con.execute(f"DESCRIBE {table}").fetchall()]
    assert columns == ["warn_check", "subject_ref", "detail"]


def test_warn_union_counts_every_table(con):
    counts = dict(con.execute("SELECT test, cnt FROM pcx__warn_union").fetchall())
    assert set(counts) == set(EXPECTED)
    for table, expected in EXPECTED.items():
        assert counts[table] >= len(expected), table


def test_every_qa_table_has_expectations():
    tables = {f.stem for f in sqltest.list_athena("pcx__qa_*.sql")} - {"pcx__qa_union"}
    assert tables == set(QA_EXPECTED)


@pytest.mark.parametrize("table", sorted(QA_EXPECTED))
def test_qa_table_fires_only_on_seeded_subjects(con, table):
    rows = con.execute(f"SELECT qa_check, subject_ref, detail FROM {table}").fetchall()
    assert {(check, subject) for check, subject, _ in rows} == QA_EXPECTED[table]
    assert all(check is not None and detail for check, _, detail in rows)


def test_qa_athena_toml_lists_every_warn_table():
    import tomllib
    from cumulus_library_pcx.tools import filetool
    toml = tomllib.loads(filetool.path_project("qa_athena.toml").read_text())
    listed = {pathlib.Path(f).stem for action in toml["actions"] for f in action["files"]}
    assert listed >= {f.stem for f in sqltest.list_athena("pcx__warn_*.sql")}
    assert listed >= {f.stem for f in sqltest.list_athena("pcx__qa_*.sql")}
