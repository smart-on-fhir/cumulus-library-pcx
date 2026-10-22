-- ============================================================================
-- Warning: treatment evidence exists, but its timing against t0 or the
-- initial-therapy window is unknown.
--
-- Dates are ranges (pcx__exposure_record): a month or year date covers its
-- whole period and an undated mention ends at its note date. A comparison
-- that the range does not settle is unknown, never guessed. These rows show
-- where that happens and why, one row per subject x exposure x check.
--
--   prior_to_t0_unknown           a month or year date straddles t0_day, so
--                                 *_prior_to_t0_bool is NULL and the subject
--                                 is out of pcx__eligible_trial
--   initial_unknown_event_timing  an undated progression, recurrence or second
--                                 malignancy may precede the dated first
--                                 event, so the window end is unknown
--   initial_unknown_possible_record  a record may fall inside the window: a
--                                 range crossing t0 or the first event, or an
--                                 undated mention whose note is dated on or
--                                 after t0 with no dated record before it
--   initial_unknown_outside_window_only  every record is outside the window,
--                                 but nothing documents initial therapy
--                                 without it, so "no" is not established
--   methotrexate_intrathecal_or_ventricular_only  every methotrexate dose with
--                                 a documented route is intrathecal or
--                                 intraventricular. It counts as exposure
--                                 until the CHOP clinician settles whether
--                                 it should.
-- Exposures without any evidence are absence, not unknown, and are not listed.
-- ============================================================================
CREATE TABLE pcx__warn_exposure_timing_unknown AS

WITH exposure AS (
    SELECT  elig.subject_ref,
            elig.t0_day,
            'methotrexate'                              AS exposure,
            rx.methotrexate_any_bool                    AS any_bool,
            rx.methotrexate_first_day                   AS first_day,
            rx.methotrexate_prior_to_t0_bool            AS prior_to_t0_bool,
            outcome.had_initial_methotrexate_bool       AS had_initial_bool,
            outcome.methotrexate_initial_unknown_reason AS unknown_reason
    FROM    pcx__eligible           AS elig
    JOIN    pcx__eligible_rx        AS rx       ON rx.subject_ref      = elig.subject_ref
    JOIN    pcx__outcome_exposure   AS outcome  ON outcome.subject_ref = elig.subject_ref
    UNION ALL
    SELECT  elig.subject_ref, elig.t0_day, 'chemo', rx.chemo_any_bool, rx.chemo_first_day,
            rx.chemo_prior_to_t0_bool, outcome.had_initial_chemo_bool, outcome.chemo_initial_unknown_reason
    FROM    pcx__eligible           AS elig
    JOIN    pcx__eligible_rx        AS rx       ON rx.subject_ref      = elig.subject_ref
    JOIN    pcx__outcome_exposure   AS outcome  ON outcome.subject_ref = elig.subject_ref
    UNION ALL
    SELECT  elig.subject_ref, elig.t0_day, 'radiation', rt.radiation_any_bool, rt.radiation_first_day,
            rt.radiation_prior_to_t0_bool, outcome.had_initial_radiation_bool, outcome.radiation_initial_unknown_reason
    FROM    pcx__eligible           AS elig
    JOIN    pcx__eligible_radiation AS rt       ON rt.subject_ref      = elig.subject_ref
    JOIN    pcx__outcome_exposure   AS outcome  ON outcome.subject_ref = elig.subject_ref
),
flagged AS (
    SELECT  subject_ref, t0_day, exposure, first_day, had_initial_bool,
            'prior_to_t0_unknown'                                               AS warn_check
    FROM    exposure
    WHERE   t0_day IS NOT NULL
    AND     prior_to_t0_bool IS NULL
    UNION ALL
    SELECT  subject_ref, t0_day, exposure, first_day, had_initial_bool,
            CASE unknown_reason
                WHEN 'event_timing_uncertain'           THEN 'initial_unknown_event_timing'
                WHEN 'possible_record'                  THEN 'initial_unknown_possible_record'
                WHEN 'no_initial_therapy_documented'    THEN 'initial_unknown_outside_window_only'
            END
    FROM    exposure
    WHERE   any_bool
    AND     unknown_reason IN ('event_timing_uncertain', 'possible_record', 'no_initial_therapy_documented')
),
methotrexate_route AS (
    SELECT  subject_ref,
            MIN(exposure_day)                                                   AS first_day
    FROM    pcx__exposure_record
    WHERE   exposure = 'methotrexate'
    GROUP BY subject_ref
    HAVING  BOOL_OR(route IN ('INTRATHECAL', 'INTRAVENTRICULAR'))
    AND     NOT BOOL_OR(route NOT IN ('INTRATHECAL', 'INTRAVENTRICULAR'))
)

SELECT  warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('exposure=',     exposure),
            CONCAT('first=',        CAST(first_day AS VARCHAR)),
            CONCAT('t0=',           CAST(t0_day AS VARCHAR)),
            CONCAT('had_initial=',  CAST(had_initial_bool AS VARCHAR)))         AS detail
FROM    flagged

UNION ALL

SELECT  'methotrexate_intrathecal_or_ventricular_only'                          AS warn_check,
        CAST(route.subject_ref AS VARCHAR)                                      AS subject_ref,
        CONCAT_WS('|',
            CONCAT('first=',        CAST(route.first_day AS VARCHAR)),
            CONCAT('had_initial=',  CAST(outcome.had_initial_methotrexate_bool AS VARCHAR)))
                                                                                AS detail
FROM    methotrexate_route              AS route
JOIN    pcx__outcome_exposure           AS outcome ON outcome.subject_ref = route.subject_ref
;
