"""Run the eligible and outcome SQL (custom/) on the synthetic tables in tests/data and check
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


def eligible(con) -> dict[str, tuple]:
    rows = con.execute("SELECT subject_ref, age_under_36_months_at_definitive_surgery, atrt_confirmed_bool, "
                       "no_prior_chemotherapy_bool, no_prior_radiation_bool FROM pcx__eligible").fetchall()
    return {r[0]: r[1:] for r in rows}


def test_atrt_evidence_is_an_exclusion_not_a_case(con):
    # p1 carries a tier 3 ATRT code next to its medulloblastoma: stays a subject, tier 1 ATRT flag off
    assert con.execute("SELECT atrt_tier1_bool FROM pcx__eligible_dx WHERE subject_ref = 'Patient/p1'").fetchone() == (False,)
    assert eligible(con)['Patient/p1'][1] is False
    # p6 has an LLM ATRT diagnosis note: confirmed, and therefore out of the trial-like cohort
    assert eligible(con)['Patient/p6'][1] is True
    assert 'Patient/p6' not in {r[0] for r in con.execute("SELECT subject_ref FROM pcx__eligible_trial").fetchall()}


def test_prior_therapy_rules(con):
    rows = eligible(con)
    assert rows['Patient/p1'][2:] == (True, True)        # methotrexate and radiation after t0 only
    assert rows['Patient/p2'][2] is False                # cisplatin before t0 is prior chemotherapy
    assert rows['Patient/p3'][2] is None                 # no t0, criterion is not evaluable
    assert rows['Patient/p5'][2:] == (None, None)        # no birthdate and no therapy evidence at all


def test_trial_cohort_is_the_strict_intersection(con):
    assert (con.execute("SELECT subject_ref FROM pcx__eligible_trial ORDER BY 1").fetchall()
            == [('Patient/p1',), ('Patient/p8',)])


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
