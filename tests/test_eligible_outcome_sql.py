"""Run the eligible and outcome SQL (custom/) on the seeded fixtures in tests/data/warn and check
the trial-emulation rules, not day counts (pcx__warn_outcome_survival_days guards those on real data).
"""
from datetime import date
import pytest
from tests import sqltest


@pytest.fixture(scope="module")
def con():
    con = sqltest.connect()
    sqltest.run_custom(con)
    return con


FLAGS = ['age_under_36_months_at_t0',
         'age_under_36_months_at_definitive_surgery',
         'atrt_confirmed_bool',
         'methotrexate_prior_to_t0_bool',
         'chemo_prior_to_t0_bool',
         'radiation_prior_to_t0_bool',
         'methotrexate_any_bool',
         'chemo_any_bool',
         'radiation_any_bool']


def eligible(con) -> dict[str, dict]:
    rows = con.execute(f"SELECT subject_ref, {', '.join(FLAGS)} FROM pcx__eligible").fetchall()
    return {r[0]: dict(zip(FLAGS, r[1:])) for r in rows}


def trial(con) -> set[str]:
    return {r[0] for r in con.execute("SELECT subject_ref FROM pcx__eligible_trial").fetchall()}


def test_atrt_evidence_is_an_exclusion_not_a_case(con):
    # p1 carries a tier 3 ATRT code next to its medulloblastoma: stays a subject, tier 1 ATRT flag off
    assert con.execute("SELECT atrt_tier1_bool FROM pcx__eligible_dx WHERE subject_ref = 'Patient/p1'").fetchone() == (False,)
    assert eligible(con)['Patient/p1']['atrt_confirmed_bool'] is False
    # p6 has an LLM ATRT diagnosis note: confirmed, and therefore out of the trial-like cohort
    assert eligible(con)['Patient/p6']['atrt_confirmed_bool'] is True
    assert 'Patient/p6' not in trial(con)


def test_prior_therapy_flags(con):
    rows = eligible(con)
    prior = ['methotrexate_prior_to_t0_bool', 'chemo_prior_to_t0_bool', 'radiation_prior_to_t0_bool']
    ever = ['methotrexate_any_bool', 'chemo_any_bool', 'radiation_any_bool']
    # p1: methotrexate, chemo and radiation after t0 only
    assert [rows['Patient/p1'][f] for f in prior + ever] == [False, False, False, True, True, True]
    # p2: cisplatin before t0 is prior chemotherapy, no methotrexate at all
    assert [rows['Patient/p2'][f] for f in prior] == [False, True, False]
    # p3: no t0, so "prior" is not evaluable, while "ever" is still a plain no
    assert [rows['Patient/p3'][f] for f in prior + ever] == [None, None, None, False, False, False]
    # p5: t0 known and no therapy evidence at all is "no prior" and "never", not unknown
    assert [rows['Patient/p5'][f] for f in prior + ever] == [False, False, False, False, False, False]


def test_relaxed_criteria_are_flags_not_exclusions(con):
    rows = eligible(con)
    # p2 was 55 months old at t0 and had chemotherapy before t0: still in the discovery cohort
    assert rows['Patient/p2']['age_under_36_months_at_t0'] is False
    assert rows['Patient/p2']['age_under_36_months_at_definitive_surgery'] is False
    assert rows['Patient/p2']['chemo_prior_to_t0_bool'] is True
    assert 'Patient/p2' not in trial(con)
    # p7 was 19 months old at t0: both age flags agree
    assert (rows['Patient/p7']['age_under_36_months_at_t0'],
            rows['Patient/p7']['age_under_36_months_at_definitive_surgery']) == (True, True)


def test_prior_methotrexate_is_a_flag_here_and_an_exclusion_in_the_trial():
    # p7 plus one methotrexate order a month before its t0 (2020-01-01)
    con = sqltest.connect()
    con.execute("INSERT INTO pcx__cohort_variable_union_rx VALUES "
                "('Patient/p7', 'rx_contrast_methotrexate', DATE '2019-12-01')")
    sqltest.run_custom(con)
    row = eligible(con)['Patient/p7']
    assert (row['methotrexate_prior_to_t0_bool'], row['chemo_prior_to_t0_bool'], row['methotrexate_any_bool']) == (True, False, True)
    assert 'Patient/p7' not in trial(con)


def test_dispense_is_structured_evidence_not_receipt(con):
    rows = {r[0]: r[1:] for r in con.execute(
        "SELECT subject_ref, chemo_first_day, chemo_order_first_day, chemo_dispense_first_day, "
        "methotrexate_dispense_first_day, methotrexate_administered_bool, chemo_any_bool FROM pcx__eligible_rx").fetchall()}
    # p2: cisplatin handed over before its first order is the earliest chemo day
    assert rows['Patient/p2'][:3] == (date(2014, 10, 28), date(2014, 11, 1), date(2014, 10, 28))
    # p6: a methotrexate dispense is neither receipt nor chemotherapy
    assert rows['Patient/p6'][3:] == (date(2020, 6, 3), False, False)
    # p5: cancelled and never-handed-over dispenses are ignored, p1: a code outside the rx valuesets is ignored
    assert rows['Patient/p5'][2] is None
    assert rows['Patient/p1'][2] is None


def test_trial_cohort_is_the_strict_intersection(con):
    # p7 has t0, medulloblastoma, surgery under 36 months and no treatment evidence at all,
    # which is "no prior therapy" once t0 is known (workplan 2.2)
    assert trial(con) == {'Patient/p1', 'Patient/p7', 'Patient/p8'}


def test_surgery_type_none_of_the_above_is_a_documented_operation(con):
    # NONE_OF_THE_ABOVE means an unlisted or unstated type, not "no surgery": p3 still gets a first
    # LLM surgery day, but no definitive surgery day since the note states no role
    assert (con.execute("SELECT llm_surgery_first_day, definitive_surgery_day FROM pcx__eligible_surgery "
                       "WHERE subject_ref = 'Patient/p3'").fetchone()
            == (date(2021, 1, 10), None))


def test_first_event_and_exposure_order(con):
    rows = {r[0]: r[1:] for r in con.execute("SELECT subject_ref, first_event_type, "
                                             "methotrexate_prior_to_first_event_bool, "
                                             "radiation_prior_to_first_event_bool, "
                                             "initial_therapy_sequence, protocol_names "
                                             "FROM pcx__outcome_exposure").fetchall()}
    assert rows['Patient/p1'] == ('PROGRESSION', True, True, 'CHEMOTHERAPY_BEFORE_RADIATION', 'ACNS0334')
    assert rows['Patient/p2'] == ('DECEASED', None, True, 'CHEMOTHERAPY_BEFORE_RADIATION', 'Head Start')
    assert rows['Patient/p3'] == (None, None, None, None, None)      # no t0: nothing is ordered
    assert rows['Patient/p6'][3] == 'RADIATION_ONLY'


def test_survival_censoring(con):
    rows = {r[0]: r[1:] for r in con.execute("SELECT subject_ref, os_event_bool, os_days IS NULL, "
                                             "efs_event_bool, efs_censor_source "
                                             "FROM pcx__outcome").fetchall()}
    assert rows['Patient/p1'] == (False, False, True, 'first_event')                 # alive, progressed
    assert rows['Patient/p2'] == (True, False, True, 'first_event')                  # died
    assert rows['Patient/p3'] == (False, True, False, 'last_known_alive_provisional') # no t0: no survival interval
    assert rows['Patient/p6'] == (True, True, False, 'last_known_alive_provisional')  # deceased without a death day
