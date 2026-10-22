--  =====================================================================
--  Outcome: treatment exposure in initial therapy (README section 2)
--
--  Initial therapy runs from time zero to the first event: an exposure is
--  initial when its first day ON OR AFTER t0_day is BEFORE first_event_day.
--  With no dated event the window is open-ended. A death without a date
--  follows every dated exposure, since the patient was alive for it.
--  Exposure definitions come from pcx__eligible_rx (methotrexate, chemo) and
--  pcx__eligible_radiation (radiation).
--
--  had_initial_methotrexate_bool / _chemo_bool / _radiation_bool
--    TRUE   a dated exposure in the window
--    FALSE  none in the window and none undated, and initial therapy is
--           documented without it: for methotrexate and radiation a dated
--           chemotherapy in the window, for chemotherapy a dated radiation in
--           the window. An explicit EXPLICITLY_NOT_RECEIVED also gives FALSE
--           for methotrexate and radiation.
--    NULL   unknown: no t0, an undated progression, recurrence or second
--           malignancy (event_timing_uncertain_bool, the window end is
--           unknown), an undated exposure that may fall in the window, or no
--           initial therapy documented at all. Missing documentation is
--           never read as "not given".
--  initial_therapy_sequence orders chemotherapy and radiation inside the
--  window (Sarah's stratifier), from the same flags:
--    CHEMOTHERAPY_BEFORE_RADIATION, RADIATION_BEFORE_CHEMOTHERAPY, SAME_DAY
--                       both initial, by first day in the window
--    CHEMOTHERAPY_ONLY  chemo initial, radiation FALSE
--    RADIATION_ONLY     radiation initial, chemo FALSE
--    NO_INITIAL_THERAPY t0 known, timing certain, dated chemotherapy or
--                       radiation exists but none of it is in the window and
--                       none is undated
--    NULL               unknown
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
evidence AS (
    SELECT  elig.subject_ref,
            elig.t0_day,
            event.first_event_day,
            event.first_event_type,
            COALESCE(event.event_timing_uncertain_bool, FALSE)                      AS event_timing_uncertain_bool,
            rx.methotrexate_first_day,
            rx.chemo_first_day,
            rt.radiation_first_day,
            rx.methotrexate_first_day_from_t0,
            rx.chemo_first_day_from_t0,
            rt.radiation_first_day_from_t0,
            rx.methotrexate_undated_bool,
            rx.chemo_undated_bool,
            rt.radiation_undated_bool,
            rx.methotrexate_not_received_bool,
            COALESCE(rt.llm_explicitly_not_received_bool, FALSE)                    AS radiation_not_received_bool,
            -- a dated exposure inside the window, never NULL
            (rx.methotrexate_first_day_from_t0 IS NOT NULL
             AND (event.first_event_day IS NULL OR rx.methotrexate_first_day_from_t0 < event.first_event_day))
                                                                                    AS methotrexate_in_window_bool,
            (rx.chemo_first_day_from_t0 IS NOT NULL
             AND (event.first_event_day IS NULL OR rx.chemo_first_day_from_t0 < event.first_event_day))
                                                                                    AS chemo_in_window_bool,
            (rt.radiation_first_day_from_t0 IS NOT NULL
             AND (event.first_event_day IS NULL OR rt.radiation_first_day_from_t0 < event.first_event_day))
                                                                                    AS radiation_in_window_bool
    FROM    pcx__eligible              AS elig
    JOIN    pcx__eligible_rx           AS rx    ON rx.subject_ref    = elig.subject_ref
    JOIN    pcx__eligible_radiation    AS rt    ON rt.subject_ref    = elig.subject_ref
    LEFT JOIN pcx__outcome_first_event AS event ON event.subject_ref = elig.subject_ref
),
initial AS (
    SELECT  evidence.*,
            CASE
                WHEN t0_day IS NULL OR event_timing_uncertain_bool          THEN NULL
                WHEN methotrexate_in_window_bool                            THEN TRUE
                WHEN methotrexate_undated_bool                              THEN NULL
                WHEN chemo_in_window_bool OR methotrexate_not_received_bool THEN FALSE
            END                                                             AS had_initial_methotrexate_bool,
            CASE
                WHEN t0_day IS NULL OR event_timing_uncertain_bool          THEN NULL
                WHEN chemo_in_window_bool                                   THEN TRUE
                WHEN chemo_undated_bool                                     THEN NULL
                WHEN radiation_in_window_bool                               THEN FALSE
            END                                                             AS had_initial_chemo_bool,
            CASE
                WHEN t0_day IS NULL OR event_timing_uncertain_bool          THEN NULL
                WHEN radiation_in_window_bool                               THEN TRUE
                WHEN radiation_undated_bool                                 THEN NULL
                WHEN chemo_in_window_bool OR radiation_not_received_bool    THEN FALSE
            END                                                             AS had_initial_radiation_bool
    FROM    evidence
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
             AND chemo_first_day_from_t0 < radiation_first_day_from_t0          THEN 'CHEMOTHERAPY_BEFORE_RADIATION'
            WHEN had_initial_chemo_bool AND had_initial_radiation_bool
             AND chemo_first_day_from_t0 > radiation_first_day_from_t0          THEN 'RADIATION_BEFORE_CHEMOTHERAPY'
            WHEN had_initial_chemo_bool AND had_initial_radiation_bool          THEN 'SAME_DAY'
            WHEN had_initial_chemo_bool AND NOT had_initial_radiation_bool      THEN 'CHEMOTHERAPY_ONLY'
            WHEN had_initial_radiation_bool AND NOT had_initial_chemo_bool      THEN 'RADIATION_ONLY'
            WHEN t0_day IS NOT NULL
             AND NOT event_timing_uncertain_bool
             AND NOT chemo_undated_bool
             AND NOT radiation_undated_bool
             AND (chemo_first_day IS NOT NULL OR radiation_first_day IS NOT NULL)
             AND NOT chemo_in_window_bool
             AND NOT radiation_in_window_bool                                   THEN 'NO_INITIAL_THERAPY'
        END                                                                     AS initial_therapy_sequence,
        protocol.protocol_names
FROM    initial
LEFT JOIN protocol ON protocol.subject_ref = initial.subject_ref
;
