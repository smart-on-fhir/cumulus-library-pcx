--  =====================================================================
--  Outcome: treatment exposure in initial therapy (README section 2)
--
--  Initial therapy runs from time zero to the first event. Every record in
--  pcx__exposure_record has the range of days it can fall on (a month or
--  year date covers the whole period, an undated mention ends at its note
--  date), and the first event a range too (pcx__outcome_first_event). Each
--  record is placed against the window [t0_day, first event):
--    inside    certainly in it: starts on or after t0_day, and ends before
--              the first event can have happened (or there is no dated event)
--    outside   certainly not in it: ends before t0_day, or starts on or after
--              the latest day the first event can be
--    possible  could be either, including an undated mention whose note is
--              dated on or after t0_day
--    restated  an undated mention of treatment already on record on or before
--              its note date (pcx__exposure_record.restated_bool), ignored
--  A death without a date follows every dated exposure, since the patient was
--  alive for it.
--
--  had_initial_methotrexate_bool / _chemo_bool / _radiation_bool
--    TRUE   a record inside the window
--    FALSE  no record inside or possibly inside, and initial therapy is
--           documented without it: for methotrexate and radiation a
--           chemotherapy record inside the window, for chemotherapy a
--           radiation record inside it. An explicit EXPLICITLY_NOT_RECEIVED
--           also gives FALSE for methotrexate and radiation.
--    NULL   unknown: no t0, an undated progression, recurrence or second
--           malignancy of unknown timing (event_timing_uncertain_bool), a
--           record possibly inside, or no initial therapy documented at all.
--           Missing documentation is never read as "not given".
--  initial_therapy_sequence orders chemotherapy and radiation inside the
--  window (Sarah's stratifier). Each exposure's first day in the window lies
--  between the earliest day any inside or possible record could be (not
--  before t0_day) and the earliest end of an inside record:
--    CHEMOTHERAPY_BEFORE_RADIATION / RADIATION_BEFORE_CHEMOTHERAPY
--                       both initial, and one certainly starts first
--    SAME_DAY           both initial on the same exact day
--    CHEMOTHERAPY_ONLY  chemo initial, radiation FALSE
--    RADIATION_ONLY     radiation initial, chemo FALSE
--    NO_INITIAL_THERAPY t0 known, timing certain, chemotherapy or radiation
--                       records exist and every one is outside the window
--    NULL               unknown, including overlapping coarse dates
--  protocol_names is every distinct protocol named in regimen or anchor evidence.
--  =====================================================================
CREATE  TABLE   pcx__outcome_exposure AS
WITH
protocol_candidate AS (
    SELECT  subject_ref, protocol_name_verbatim AS protocol_name
    FROM    pcx__llm_systemic_therapy_regimen
    WHERE   protocol_name_verbatim IS NOT NULL
    UNION
    SELECT  subject_ref, protocol_name
    FROM    pcx__llm_survival_timeline_anchor
    WHERE   protocol_name IS NOT NULL
),
protocol AS (
    SELECT  subject_ref,
            ARRAY_JOIN(ARRAY_AGG(protocol_name ORDER BY protocol_name), ' | ')      AS protocol_names
    FROM    protocol_candidate
    GROUP BY subject_ref
),
-- each record placed against the initial-therapy window
placed AS (
    SELECT  record.subject_ref,
            record.exposure,
            record.earliest_day,
            record.latest_day,
            elig.t0_day,
            CASE
                WHEN record.restated_bool                                           THEN 'restated'
                WHEN record.latest_day < elig.t0_day                                THEN 'outside'
                WHEN record.earliest_day >= event.first_event_latest_day            THEN 'outside'
                WHEN record.earliest_day >= elig.t0_day
                 AND (event.first_event_earliest_day IS NULL
                      OR record.latest_day < event.first_event_earliest_day)        THEN 'inside'
                ELSE                                                                     'possible'
            END                                                                     AS window_position
    FROM    pcx__exposure_record       AS record
    JOIN    pcx__eligible              AS elig  ON elig.subject_ref  = record.subject_ref
    LEFT JOIN pcx__outcome_first_event AS event ON event.subject_ref = record.subject_ref
    WHERE   record.exposure IN ('methotrexate', 'chemo', 'radiation')
    AND     elig.t0_day IS NOT NULL
),
in_window AS (
    SELECT  subject_ref,
            BOOL_OR(exposure = 'methotrexate' AND window_position = 'inside')              AS methotrexate_inside_bool,
            BOOL_OR(exposure = 'methotrexate' AND window_position = 'possible')            AS methotrexate_possible_bool,
            BOOL_OR(exposure = 'chemo'        AND window_position = 'inside')              AS chemo_inside_bool,
            BOOL_OR(exposure = 'chemo'        AND window_position = 'possible')            AS chemo_possible_bool,
            BOOL_OR(exposure = 'radiation'    AND window_position = 'inside')              AS radiation_inside_bool,
            BOOL_OR(exposure = 'radiation'    AND window_position = 'possible')            AS radiation_possible_bool,
            BOOL_OR(exposure IN ('chemo', 'radiation') AND window_position <> 'restated')  AS therapy_recorded_bool,
            -- range of each exposure's first day in the window
            MIN(CASE WHEN exposure = 'chemo' AND window_position IN ('inside', 'possible')
                     THEN CASE WHEN earliest_day >= t0_day THEN earliest_day ELSE t0_day END END)
                                                                                    AS chemo_initial_earliest_day,
            MIN(CASE WHEN exposure = 'chemo' AND window_position = 'inside' THEN latest_day END)
                                                                                    AS chemo_initial_latest_day,
            MIN(CASE WHEN exposure = 'radiation' AND window_position IN ('inside', 'possible')
                     THEN CASE WHEN earliest_day >= t0_day THEN earliest_day ELSE t0_day END END)
                                                                                    AS radiation_initial_earliest_day,
            MIN(CASE WHEN exposure = 'radiation' AND window_position = 'inside' THEN latest_day END)
                                                                                    AS radiation_initial_latest_day
    FROM    placed
    GROUP BY subject_ref
),
initial AS (
    SELECT  elig.subject_ref,
            elig.t0_day,
            event.first_event_day,
            event.first_event_type,
            COALESCE(event.event_timing_uncertain_bool, FALSE)                      AS event_timing_uncertain_bool,
            rx.methotrexate_first_day,
            rx.chemo_first_day,
            rt.radiation_first_day,
            in_window.methotrexate_inside_bool,
            in_window.chemo_inside_bool,
            in_window.chemo_possible_bool,
            in_window.radiation_inside_bool,
            in_window.radiation_possible_bool,
            in_window.therapy_recorded_bool,
            in_window.chemo_initial_earliest_day,
            in_window.chemo_initial_latest_day,
            in_window.radiation_initial_earliest_day,
            in_window.radiation_initial_latest_day,
            CASE
                WHEN elig.t0_day IS NULL OR event.event_timing_uncertain_bool       THEN NULL
                WHEN in_window.methotrexate_inside_bool                                THEN TRUE
                WHEN in_window.methotrexate_possible_bool                              THEN NULL
                WHEN in_window.chemo_inside_bool OR rx.methotrexate_not_received_bool  THEN FALSE
            END                                                                     AS had_initial_methotrexate_bool,
            CASE
                WHEN elig.t0_day IS NULL OR event.event_timing_uncertain_bool       THEN NULL
                WHEN in_window.chemo_inside_bool                                       THEN TRUE
                WHEN in_window.chemo_possible_bool                                     THEN NULL
                WHEN in_window.radiation_inside_bool                                   THEN FALSE
            END                                                                     AS had_initial_chemo_bool,
            CASE
                WHEN elig.t0_day IS NULL OR event.event_timing_uncertain_bool       THEN NULL
                WHEN in_window.radiation_inside_bool                                   THEN TRUE
                WHEN in_window.radiation_possible_bool                                 THEN NULL
                WHEN in_window.chemo_inside_bool OR rt.llm_explicitly_not_received_bool THEN FALSE
            END                                                                     AS had_initial_radiation_bool
    FROM    pcx__eligible              AS elig
    JOIN    pcx__eligible_rx           AS rx    ON rx.subject_ref     = elig.subject_ref
    JOIN    pcx__eligible_radiation    AS rt    ON rt.subject_ref     = elig.subject_ref
    LEFT JOIN pcx__outcome_first_event AS event ON event.subject_ref  = elig.subject_ref
    LEFT JOIN in_window                         ON in_window.subject_ref = elig.subject_ref
)
SELECT  initial.subject_ref,
        initial.t0_day,
        initial.first_event_day,
        initial.first_event_type,
        initial.event_timing_uncertain_bool,
        initial.methotrexate_first_day,
        initial.chemo_first_day,
        initial.radiation_first_day,
        initial.had_initial_methotrexate_bool,
        initial.had_initial_chemo_bool,
        initial.had_initial_radiation_bool,
        CASE
            WHEN had_initial_chemo_bool AND had_initial_radiation_bool
             AND chemo_initial_latest_day < radiation_initial_earliest_day          THEN 'CHEMOTHERAPY_BEFORE_RADIATION'
            WHEN had_initial_chemo_bool AND had_initial_radiation_bool
             AND radiation_initial_latest_day < chemo_initial_earliest_day          THEN 'RADIATION_BEFORE_CHEMOTHERAPY'
            WHEN had_initial_chemo_bool AND had_initial_radiation_bool
             AND chemo_initial_earliest_day = chemo_initial_latest_day
             AND radiation_initial_earliest_day = radiation_initial_latest_day
             AND chemo_initial_earliest_day = radiation_initial_earliest_day        THEN 'SAME_DAY'
            WHEN had_initial_chemo_bool AND NOT had_initial_radiation_bool          THEN 'CHEMOTHERAPY_ONLY'
            WHEN had_initial_radiation_bool AND NOT had_initial_chemo_bool          THEN 'RADIATION_ONLY'
            WHEN t0_day IS NOT NULL
             AND NOT event_timing_uncertain_bool
             AND therapy_recorded_bool
             AND NOT (chemo_inside_bool OR chemo_possible_bool
                      OR radiation_inside_bool OR radiation_possible_bool)          THEN 'NO_INITIAL_THERAPY'
        END                                                                         AS initial_therapy_sequence,
        protocol.protocol_names
FROM    initial
LEFT JOIN protocol ON protocol.subject_ref = initial.subject_ref
;
