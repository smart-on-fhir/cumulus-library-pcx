-- ============================================================================
-- Warning: exposure counted as received without administration evidence.
--
-- README section 2 asks for ACTUAL administration. pcx__eligible_rx unions
-- MedicationRequest orders (authoredOn) with LLM ADMINISTERED agents and takes
-- the earliest day, and pcx__eligible_radiation does the same with procedure
-- and encounter codes. methotrexate_first_day / radiation_first_day, and so
-- every prior-to-first-event flag and initial_therapy_sequence, can therefore
-- rest on an order or an encounter code alone.
--
--   methotrexate_order_only   methotrexate ordered, never LLM-administered
--   radiation_code_only       radiation coded, never LLM-administered
--   chemo_order_only          backbone chemo ordered, never LLM-administered
-- ============================================================================
CREATE TABLE pcx__warn_outcome_exposure_order_only AS

SELECT  'methotrexate_order_only'                                               AS warn_check,
        CAST(rx.subject_ref AS VARCHAR)                                         AS subject_ref,
        CONCAT_WS('|',
            CONCAT('order_first=',      CAST(rx.methotrexate_order_first_day AS VARCHAR)),
            CONCAT('prior_to_first_event=', CAST(exposure.methotrexate_prior_to_first_event_bool AS VARCHAR)),
            CONCAT('first_event=',      CAST(exposure.first_event_day AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_rx        AS rx
JOIN    pcx__outcome_exposure   AS exposure ON exposure.subject_ref = rx.subject_ref
WHERE   rx.methotrexate_any_bool
AND     NOT COALESCE(rx.methotrexate_administered_bool, FALSE)

UNION ALL

SELECT  'radiation_code_only'                                                   AS warn_check,
        CAST(radiation.subject_ref AS VARCHAR)                                  AS subject_ref,
        CONCAT_WS('|',
            CONCAT('proc_first=',       CAST(radiation.radiation_proc_first_day AS VARCHAR)),
            CONCAT('dx_first=',         CAST(radiation.radiation_dx_first_day AS VARCHAR)),
            CONCAT('prior_to_first_event=', CAST(exposure.radiation_prior_to_first_event_bool AS VARCHAR)),
            CONCAT('first_event=',      CAST(exposure.first_event_day AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_radiation AS radiation
JOIN    pcx__outcome_exposure   AS exposure ON exposure.subject_ref = radiation.subject_ref
WHERE   radiation.radiation_any_bool
AND     NOT COALESCE(radiation.radiation_administered_bool, FALSE)

UNION ALL

SELECT  'chemo_order_only'                                                      AS warn_check,
        CAST(rx.subject_ref AS VARCHAR)                                         AS subject_ref,
        CONCAT_WS('|',
            CONCAT('order_first=',      CAST(rx.chemo_order_first_day AS VARCHAR)),
            CONCAT('sequence=',         exposure.initial_therapy_sequence),
            CONCAT('first_event=',      CAST(exposure.first_event_day AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_rx        AS rx
JOIN    pcx__outcome_exposure   AS exposure ON exposure.subject_ref = rx.subject_ref
WHERE   rx.chemo_any_bool
AND     rx.chemo_administered_first_day IS NULL
;
