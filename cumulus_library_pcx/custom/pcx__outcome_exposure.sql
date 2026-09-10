--  =====================================================================
--  Outcome: treatment exposure relative to the first event (README section 2)
--
--  methotrexate_prior_to_first_event_bool / radiation_prior_to_first_event_bool
--    TRUE   first exposure day is before the first event day, or there is no event
--    FALSE  first exposure day is on or after the first event day (salvage, not initial therapy)
--    NULL   no dated exposure evidence at all (unknown, not confirmed absence)
--  initial_therapy_sequence compares first chemo day with first radiation day,
--  both restricted to before the first event (Sarah's stratifier).
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
    FROM    pcx__llm_patient_anchor
    WHERE   protocol_name IS NOT NULL
),
protocol AS (
    SELECT  subject_ref,
            ARRAY_JOIN(ARRAY_AGG(protocol_name ORDER BY protocol_name), ' | ')      AS protocol_names
    FROM    protocol_candidate
    GROUP BY subject_ref
),
timing AS (
    SELECT  elig.subject_ref,
            elig.t0_day,
            event.first_event_day,
            event.first_event_type,
            elig.methotrexate_first_day,
            elig.chemo_first_day,
            elig.radiation_first_day,
            CASE
                WHEN elig.methotrexate_first_day IS NULL    THEN NULL
                WHEN event.first_event_day IS NULL          THEN TRUE
                ELSE elig.methotrexate_first_day < event.first_event_day
            END                                                                 AS methotrexate_prior_to_first_event_bool,
            CASE
                WHEN elig.chemo_first_day IS NULL           THEN NULL
                WHEN event.first_event_day IS NULL          THEN TRUE
                ELSE elig.chemo_first_day < event.first_event_day
            END                                                                 AS chemo_prior_to_first_event_bool,
            CASE
                WHEN elig.radiation_first_day IS NULL       THEN NULL
                WHEN event.first_event_day IS NULL          THEN TRUE
                ELSE elig.radiation_first_day < event.first_event_day
            END                                                                 AS radiation_prior_to_first_event_bool
    FROM    pcx__eligible              AS elig
    LEFT JOIN pcx__outcome_first_event AS event ON event.subject_ref = elig.subject_ref
)
SELECT  timing.*,
        CASE
            WHEN chemo_prior_to_first_event_bool AND radiation_prior_to_first_event_bool
             AND chemo_first_day < radiation_first_day                          THEN 'CHEMOTHERAPY_BEFORE_RADIATION'
            WHEN chemo_prior_to_first_event_bool AND radiation_prior_to_first_event_bool
             AND chemo_first_day > radiation_first_day                          THEN 'RADIATION_BEFORE_CHEMOTHERAPY'
            WHEN chemo_prior_to_first_event_bool AND radiation_prior_to_first_event_bool
                                                                                THEN 'SAME_DAY'
            WHEN chemo_prior_to_first_event_bool                                THEN 'CHEMOTHERAPY_ONLY'
            WHEN radiation_prior_to_first_event_bool                            THEN 'RADIATION_ONLY'
            ELSE NULL
        END                                                                     AS initial_therapy_sequence,
        protocol.protocol_names
FROM    timing
LEFT JOIN protocol ON protocol.subject_ref = timing.subject_ref
;