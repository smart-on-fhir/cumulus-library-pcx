-- ============================================================================
-- Warning: radiation evidence that pcx__eligible_radiation cannot reconcile.
--
--   radiation_not_received_vs_evidence   an LLM note says radiation was
--                                        EXPLICITLY_NOT_RECEIVED while another
--                                        source (procedure code, encounter
--                                        code, or LLM ADMINISTERED) dates a
--                                        delivery
--   radiation_history_code_ignored       a tier 2 "personal history of
--                                        irradiation" code (Z92.3 / V15.3)
--                                        recorded on or before t0_day, which
--                                        eligible_radiation drops (tier = 1
--                                        only) although it is exactly the
--                                        prior-radiation signal ACNS0334 asks
--                                        about
-- ============================================================================
CREATE TABLE pcx__warn_eligible_radiation_evidence_conflict AS

WITH history_code AS (
    SELECT  subject_ref,
            MIN(dx_recorded_date)       AS history_first_day,
            COUNT(DISTINCT condition_ref) AS condition_cnt
    FROM    pcx__cohort_dx_radiation
    WHERE   tier = 2
    GROUP BY subject_ref
)

SELECT  'radiation_not_received_vs_evidence'                                    AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('first=',            CAST(radiation_first_day AS VARCHAR)),
            CONCAT('proc=',             CAST(radiation_proc_first_day AS VARCHAR)),
            CONCAT('dx=',               CAST(radiation_dx_first_day AS VARCHAR)),
            CONCAT('llm_administered=', CAST(radiation_administered_first_day AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_radiation
WHERE   llm_explicitly_not_received_bool
AND     radiation_first_day IS NOT NULL

UNION ALL

SELECT  'radiation_history_code_ignored'                                        AS warn_check,
        CAST(radiation.subject_ref AS VARCHAR)                                  AS subject_ref,
        CONCAT_WS('|',
            CONCAT('history_first=',    CAST(history.history_first_day AS VARCHAR)),
            CONCAT('t0=',               CAST(radiation.t0_day AS VARCHAR)),
            CONCAT('conditions=',       CAST(history.condition_cnt AS VARCHAR)),
            CONCAT('no_prior_radiation_input=', CAST(radiation.radiation_prior_to_t0_bool AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_radiation AS radiation
JOIN    history_code            AS history ON history.subject_ref = radiation.subject_ref
WHERE   radiation.t0_day IS NOT NULL
AND     history.history_first_day <= radiation.t0_day
AND     NOT COALESCE(radiation.radiation_prior_to_t0_bool, FALSE)
;
