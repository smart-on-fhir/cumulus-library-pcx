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


def test_t0_prefers_the_llm_gold_diagnosis_day(con):
    rows = {r[0]: r[1:] for r in con.execute(
        "SELECT subject_ref, t0_day, t0_source, casedef_t0_day FROM pcx__eligible_dx").fetchall()}
    # p1: day-precision gold date (2020-01-28) wins over the tier 1 code encounter (2020-02-01)
    assert rows['Patient/p1'] == (date(2020, 1, 28), 'llm_diagnosis_gold', date(2020, 2, 1))
    # p6: a month-precision gold date never sets t0, so the tier 1 code does
    assert rows['Patient/p6'] == (date(2020, 5, 1), 'casedef_tier1_medulloblastoma', date(2020, 5, 1))
    # p3: no day-precision gold date and no tier 1 code: no t0 and no source
    assert rows['Patient/p3'] == (None, None, None)


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
    # p2 was 54 months old at t0 (its gold diagnosis day) and had chemotherapy before t0: still in the discovery cohort
    assert rows['Patient/p2']['age_under_36_months_at_t0'] is False
    assert rows['Patient/p2']['age_under_36_months_at_definitive_surgery'] is False
    assert rows['Patient/p2']['chemo_prior_to_t0_bool'] is True
    assert 'Patient/p2' not in trial(con)
    # p7 was 19 months old at t0: both age flags agree
    assert (rows['Patient/p7']['age_under_36_months_at_t0'],
            rows['Patient/p7']['age_under_36_months_at_definitive_surgery']) == (True, True)


def test_prior_methotrexate_is_a_flag_here_and_an_exclusion_in_the_trial():
    # p7 plus one methotrexate order a month before its t0 (2020-01-01): structured
    # methotrexate is evidence only, so p7 is not exposed and stays in the trial view
    order = ("INSERT INTO pcx__cohort_variable_union_rx VALUES "
             "('Patient/p7', 'rx_contrast_methotrexate', DATE '2019-12-01')")
    con = sqltest.connect()
    con.execute(order)
    sqltest.run_custom(con)
    row = eligible(con)['Patient/p7']
    assert (row['methotrexate_prior_to_t0_bool'], row['chemo_prior_to_t0_bool'], row['methotrexate_any_bool']) == (False, False, False)
    assert 'Patient/p7' in trial(con)
    # plus an explicitly high-dose methotrexate dose given that day: prior methotrexate,
    # which is also prior chemotherapy, so p7 leaves the trial view
    con = sqltest.connect()
    con.execute(order)
    con.execute("INSERT INTO pcx__llm_systemic_therapy_agent (subject_ref, note_ref, delivery_status, agent_name, "
                "regimen_index, agent_index) VALUES ('Patient/p7', 'note-p7-rx', 'NONE_OF_THE_ABOVE', 'METHOTREXATE', 1, 1)")
    con.execute("INSERT INTO pcx__llm_systemic_therapy_administration (subject_ref, note_ref, administration_day, "
                "regimen_index, agent_index, delivery_status, high_dose_methotrexate_explicit_bool) VALUES "
                "('Patient/p7', 'note-p7-rx', DATE '2019-12-01', 1, 1, 'ADMINISTERED', TRUE)")
    sqltest.run_custom(con)
    row = eligible(con)['Patient/p7']
    assert (row['methotrexate_prior_to_t0_bool'], row['chemo_prior_to_t0_bool'], row['methotrexate_any_bool']) == (True, True, True)
    assert 'Patient/p7' not in trial(con)


def test_methotrexate_is_any_administration_or_acns0334_regimen_b(con):
    rows = {r[0]: r[1:] for r in con.execute(
        "SELECT subject_ref, methotrexate_source, methotrexate_first_day, methotrexate_regimen_b_first_day, "
        "methotrexate_high_dose_first_day, methotrexate_intrathecal_or_ventricular_first_day, "
        "chemo_administered_first_day FROM pcx__eligible_rx").fetchall()}
    # p1: on ACNS0334 Regimen B with no regimen start date, dated by its administered methotrexate.
    # Its cisplatin agent is only PLANNED, but a cisplatin dose is ADMINISTERED: dose-level receipt is chemo.
    assert rows['Patient/p1'] == ('llm_acns0334_regimen_b,llm_administered', date(2020, 2, 12), date(2020, 2, 12),
                                  None, None, date(2020, 2, 5))
    # p8: any administered methotrexate counts (CHOP: any methotrexate is high-dose), so the earlier
    # intrathecal dose is the first day. The high-dose label and the route are kept as evidence.
    assert rows['Patient/p8'] == ('llm_administered', date(2021, 1, 15), None,
                                  date(2021, 2, 1), date(2021, 1, 15), date(2021, 1, 15))


def test_dispense_is_structured_evidence_not_receipt(con):
    rows = {r[0]: r[1:] for r in con.execute(
        "SELECT subject_ref, chemo_first_day, chemo_order_first_day, chemo_dispense_first_day, "
        "methotrexate_dispense_first_day, methotrexate_any_bool, chemo_any_bool FROM pcx__eligible_rx").fetchall()}
    # p2: cisplatin handed over before its first order is the earliest chemo day
    assert rows['Patient/p2'][:3] == (date(2014, 10, 28), date(2014, 11, 1), date(2014, 10, 28))
    # p6: a methotrexate dispense is evidence only: neither methotrexate exposure nor chemotherapy
    assert rows['Patient/p6'][3:] == (date(2020, 6, 3), False, False)
    # p5: cancelled and never-handed-over dispenses are ignored, p1: a code outside the rx valuesets is ignored
    assert rows['Patient/p5'][2] is None
    assert rows['Patient/p1'][2] is None


def test_event_task_death_reaches_os_and_efs_alike():
    # p5: alive by every other source, the event task documents death on 2021-06-01.
    # p1: an undated event-task death, beside its dated progression on 2021-03-01.
    con = sqltest.connect()
    con.execute("INSERT INTO pcx__llm_event_wide (subject_ref, note_ref, event_type, event_day) VALUES "
                "('Patient/p5', 'note-p5-ev', 'DECEASED', DATE '2021-06-01'), "
                "('Patient/p1', 'note-p1-ev2', 'DECEASED', NULL)")
    sqltest.run_custom(con)
    rows = {r[0]: r[1:] for r in con.execute(
        "SELECT subject_ref, os_event_bool, death_day, os_days, efs_event_bool, first_event_day, efs_censor_source "
        "FROM pcx__outcome").fetchall()}
    # the same death ends OS and EFS: 396 days from t0 (2020-05-01)
    assert rows['Patient/p5'] == (True, date(2021, 6, 1), 396, True, date(2021, 6, 1), 'first_event')
    # an undated death is an OS event with no interval, and the dated progression stays the first EFS event
    assert rows['Patient/p1'] == (True, None, None, True, date(2021, 3, 1), 'first_event')


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
                                             "had_initial_methotrexate_bool, "
                                             "had_initial_radiation_bool, "
                                             "initial_therapy_sequence, protocol_names "
                                             "FROM pcx__outcome_exposure").fetchall()}
    assert rows['Patient/p1'] == ('PROGRESSION', True, True, 'CHEMOTHERAPY_BEFORE_RADIATION', 'ACNS0334')
    # p2: cisplatin before t0 is not initial therapy, so inside the window radiation comes first.
    # Initial chemotherapy without methotrexate is a documented "no", not unknown.
    assert rows['Patient/p2'] == ('DECEASED', False, True, 'RADIATION_BEFORE_CHEMOTHERAPY', 'Head Start')
    assert rows['Patient/p3'] == (None, None, None, None, None)      # no t0: nothing is ordered
    # p6: an undated recurrence may precede its exposures, so none is ordered against it
    assert rows['Patient/p6'][1:4] == (None, None, None)


def test_survival_censoring(con):
    rows = {r[0]: r[1:] for r in con.execute("SELECT subject_ref, os_event_bool, os_days IS NULL, "
                                             "efs_event_bool, efs_censor_source "
                                             "FROM pcx__outcome").fetchall()}
    assert rows['Patient/p1'] == (False, False, True, 'first_event')                 # alive, progressed
    assert rows['Patient/p2'] == (True, False, True, 'first_event')                  # died
    assert rows['Patient/p3'] == (False, True, False, 'last_known_alive_provisional') # no t0: no survival interval
    # p6: an undated recurrence and a death without a day are documented events, not censoring
    assert rows['Patient/p6'] == (True, True, True, 'event_timing_uncertain')


def test_undated_events_are_events_without_an_interval():
    con = sqltest.connect()
    # p6 keeps only its deceased flag without a death day
    con.execute("DELETE FROM pcx__llm_event_wide WHERE subject_ref = 'Patient/p6'")
    # p1 (progression 2021-03-01) also gets a deceased flag without a death day
    con.execute("UPDATE patient SET deceasedBoolean = TRUE WHERE id = 'p1'")
    # p8 (events 2021-01-01, methotrexate and radiation after them) gets an undated recurrence
    con.execute("INSERT INTO pcx__llm_event_wide (subject_ref, note_ref, event_type) "
                "VALUES ('Patient/p8', 'note-p8-ev-undated', 'RECURRENCE')")
    sqltest.run_custom(con)
    rows = {r[0]: r[1:] for r in con.execute("SELECT subject_ref, efs_event_bool, efs_days IS NULL, "
                                             "efs_censor_source, first_event_day, "
                                             "had_initial_methotrexate_bool, "
                                             "had_initial_radiation_bool, initial_therapy_sequence "
                                             "FROM pcx__outcome").fetchall()}
    # a death without a day is an event with no interval, after every dated exposure
    assert rows['Patient/p6'][:4] == (True, True, 'event_undated', None)
    assert rows['Patient/p6'][5:] == (True, 'RADIATION_ONLY')
    # the patient was alive at the dated progression, so it is still the first event
    assert rows['Patient/p1'] == (True, False, 'first_event', date(2021, 3, 1), True, True,
                                  'CHEMOTHERAPY_BEFORE_RADIATION')
    # dated plus undated: the dated event stays as evidence, the interval waits for reconciliation,
    # and the end of the initial window is unknown, so every initial-therapy flag is unknown
    assert rows['Patient/p8'] == (True, True, 'event_timing_uncertain', date(2021, 1, 1), None, None, None)


def initial_methotrexate(agents: list[tuple], events: list[tuple] = ()) -> tuple:
    """p5 (t0 2020-05-01, no other therapy or event evidence) with the given LLM agents and events."""
    con = sqltest.connect()
    for i, (agent, status, day) in enumerate(agents, start=1):
        con.execute("INSERT INTO pcx__llm_systemic_therapy_agent (subject_ref, note_ref, delivery_status, agent_name, "
                    "therapy_start_day, regimen_index, agent_index) VALUES ('Patient/p5', 'note-p5-rx', ?, ?, ?, 1, ?)",
                    [status, agent, day, i])
    for event_type, day in events:
        con.execute("INSERT INTO pcx__llm_event_wide (subject_ref, note_ref, event_type, event_day) "
                    "VALUES ('Patient/p5', 'note-p5-ev', ?, ?)", [event_type, day])
    sqltest.run_custom(con)
    return con.execute("SELECT had_initial_methotrexate_bool, had_initial_chemo_bool FROM pcx__outcome "
                       "WHERE subject_ref = 'Patient/p5'").fetchone()


def test_initial_methotrexate_is_yes_no_or_unknown():
    initial_chemo = ('VINCRISTINE', 'ADMINISTERED', date(2020, 6, 1))
    # any administered methotrexate in the window counts, high-dose label or not
    assert initial_methotrexate([initial_chemo, ('METHOTREXATE', 'ADMINISTERED', date(2020, 6, 8))]) == (True, True)
    # methotrexate only after progression is salvage: initial chemotherapy without it is "no"
    assert initial_methotrexate([initial_chemo, ('METHOTREXATE', 'ADMINISTERED', date(2021, 2, 1))],
                                [('PROGRESSION', date(2021, 1, 1))]) == (False, True)
    # explicit non-receipt is "no" even without other initial therapy
    assert initial_methotrexate([('METHOTREXATE', 'EXPLICITLY_NOT_RECEIVED', None)]) == (False, None)
    # an undated administration may fall in the window: unknown
    assert initial_methotrexate([initial_chemo, ('METHOTREXATE', 'ADMINISTERED', None)]) == (None, True)
    # methotrexate before t0 is not initial, and with no initial therapy documented the answer is unknown
    assert initial_methotrexate([('METHOTREXATE', 'ADMINISTERED', date(2020, 4, 1))]) == (None, None)
    # methotrexate both before t0 and inside the window: the window record counts, not the lifetime first
    assert initial_methotrexate([('METHOTREXATE', 'ADMINISTERED', date(2020, 4, 1)),
                                 ('METHOTREXATE', 'ADMINISTERED', date(2020, 6, 8))]) == (True, True)
    # no documentation at all is unknown, never "no"
    assert initial_methotrexate([]) == (None, None)


def test_sequence_uses_treatment_inside_the_window():
    con = sqltest.connect()
    # p5 (t0 2020-05-01): vincristine before diagnosis, then radiation, then vincristine again.
    # p3 (no t0): the same records, which must not be ordered at all.
    for subject in ('Patient/p5', 'Patient/p3'):
        for i, day in enumerate((date(2020, 3, 1), date(2020, 9, 1)), start=1):
            con.execute("INSERT INTO pcx__llm_systemic_therapy_agent (subject_ref, note_ref, delivery_status, "
                        "agent_name, therapy_start_day, regimen_index, agent_index) "
                        "VALUES (?, 'note-rx', 'ADMINISTERED', 'VINCRISTINE', ?, 1, ?)", [subject, day, i])
        con.execute("INSERT INTO pcx__llm_radiation_wide (subject_ref, note_ref, delivery_status, radiation_start_day) "
                    "VALUES (?, 'note-rt', 'ADMINISTERED', DATE '2020-06-01')", [subject])
    sqltest.run_custom(con)
    rows = {r[0]: r[1:] for r in con.execute(
        "SELECT subject_ref, had_initial_chemo_bool, had_initial_radiation_bool, initial_therapy_sequence "
        "FROM pcx__outcome_exposure WHERE subject_ref IN ('Patient/p5', 'Patient/p3')").fetchall()}
    # chemotherapy before diagnosis does not make p5 chemotherapy-first: radiation was first after t0
    assert rows['Patient/p5'] == (True, True, 'RADIATION_BEFORE_CHEMOTHERAPY')
    assert rows['Patient/p3'] == (None, None, None)


def p5_outcome(chemo=(), radiation=(), events=(), notes=()) -> dict:
    """p5 (t0 2020-05-01, no other therapy or events) with LLM records given as
    (day, precision, note_ref): chemo is vincristine, radiation a round, events (type, day, precision, note_ref).
    notes are (note_ref, note_date) rows of the FHIR note-date spine."""
    con = sqltest.connect()
    for i, (day, precision, note) in enumerate(chemo, start=1):
        con.execute("INSERT INTO pcx__llm_systemic_therapy_agent (subject_ref, note_ref, delivery_status, agent_name, "
                    "therapy_start_day, therapy_start_day_precision, regimen_index, agent_index) "
                    "VALUES ('Patient/p5', ?, 'ADMINISTERED', 'VINCRISTINE', ?, ?, 1, ?)", [note, day, precision, i])
    for day, precision, note in radiation:
        con.execute("INSERT INTO pcx__llm_radiation_wide (subject_ref, note_ref, delivery_status, radiation_start_day, "
                    "radiation_start_day_precision) VALUES ('Patient/p5', ?, 'ADMINISTERED', ?, ?)", [note, day, precision])
    for event_type, day, precision, note in events:
        con.execute("INSERT INTO pcx__llm_event_wide (subject_ref, note_ref, event_type, event_day, event_day_precision) "
                    "VALUES ('Patient/p5', ?, ?, ?, ?)", [note, event_type, day, precision])
    for note, note_date in notes:
        con.execute("INSERT INTO pcx__llm_note_date VALUES ('Patient/p5', ?, ?)", [note, note_date])
    sqltest.run_custom(con)
    columns = ['radiation_prior_to_t0_bool', 'had_initial_chemo_bool', 'had_initial_radiation_bool',
               'initial_therapy_sequence', 'efs_censor_source', 'first_event_day', 'efs_end_day_imputed_bool']
    row = con.execute(f"SELECT {', '.join('o.' + c if c != 'radiation_prior_to_t0_bool' else 'e.' + c for c in columns)} "
                      "FROM pcx__outcome AS o JOIN pcx__eligible AS e ON e.subject_ref = o.subject_ref "
                      "WHERE o.subject_ref = 'Patient/p5'").fetchone()
    return dict(zip(columns, row))


def test_coarse_dates_count_only_when_their_whole_period_is_on_one_side():
    chemo = [(date(2020, 6, 1), 'DAY', 'n-chemo')]
    # radiation "2020" covers t0 (2020-05-01): neither prior nor initial is certain
    row = p5_outcome(chemo, radiation=[(date(2020, 1, 1), 'YEAR', 'n-rt')])
    assert (row['radiation_prior_to_t0_bool'], row['had_initial_radiation_bool'], row['initial_therapy_sequence']) \
        == (None, None, None)
    # radiation "June 2020" is initial, but chemotherapy on 2020-06-01 falls inside that month: order unknown
    row = p5_outcome(chemo, radiation=[(date(2020, 6, 1), 'MONTH', 'n-rt')])
    assert (row['had_initial_chemo_bool'], row['had_initial_radiation_bool'], row['initial_therapy_sequence']) \
        == (True, True, None)
    # radiation "July 2020" certainly follows the chemotherapy
    row = p5_outcome(chemo, radiation=[(date(2020, 7, 1), 'MONTH', 'n-rt')])
    assert row['initial_therapy_sequence'] == 'CHEMOTHERAPY_BEFORE_RADIATION'
    # a progression "January 2021" is dated at the middle of its month for EFS, flagged as imputed
    row = p5_outcome(chemo, events=[('PROGRESSION', date(2021, 1, 1), 'MONTH', 'n-ev')])
    assert (row['efs_censor_source'], row['first_event_day'], row['efs_end_day_imputed_bool']) \
        == ('first_event', date(2021, 1, 15), True)


def test_undated_mentions_are_bounded_by_their_note_date():
    chemo = [(date(2020, 6, 1), 'DAY', 'n-chemo')]
    # radiation given before t0, restated without a date in a later note: a documented "no initial radiation"
    row = p5_outcome(chemo, radiation=[(date(2019, 1, 10), 'DAY', 'n-rt'), (None, None, 'n-rt-later')],
                     notes=[('n-rt-later', date(2021, 1, 1))])
    assert (row['had_initial_radiation_bool'], row['initial_therapy_sequence']) == (False, 'CHEMOTHERAPY_ONLY')
    # an undated mention in a note written before t0 cannot be initial therapy
    row = p5_outcome(chemo, radiation=[(None, None, 'n-rt-old')], notes=[('n-rt-old', date(2020, 3, 1))])
    assert row['had_initial_radiation_bool'] is False
    # an undated mention in a note after t0, with no dated record before it, may be initial: unknown
    row = p5_outcome(chemo, radiation=[(None, None, 'n-rt-new')], notes=[('n-rt-new', date(2020, 9, 1))])
    assert row['had_initial_radiation_bool'] is None
    progression = ('PROGRESSION', date(2021, 1, 10), 'DAY', 'n-ev')
    # "s/p recurrence" without a date in a note after the dated progression restates it: EFS keeps its interval
    row = p5_outcome(chemo, events=[progression, ('RECURRENCE', None, None, 'n-ev-later')],
                     notes=[('n-ev-later', date(2021, 6, 1))])
    assert (row['efs_censor_source'], row['first_event_day']) == ('first_event', date(2021, 1, 10))
    # the same mention in a note written before the dated progression means an earlier event: timing unknown
    row = p5_outcome(chemo, events=[progression, ('RECURRENCE', None, None, 'n-ev-early')],
                     notes=[('n-ev-early', date(2020, 11, 1))])
    assert row['efs_censor_source'] == 'event_timing_uncertain'
