-- ============================================================================
-- Warning: vital-status evidence that pcx__outcome_vital_status had to force.
--
--   death_day_disagree          FHIR deceasedDateTime and LLM death_date both
--                               present and different (earliest wins)
--   deceased_without_death_day  a deceased flag with no date from any source,
--                               so os_event_bool is TRUE and os_days is NULL
--   alive_after_death           last_known_alive_day is later than death_day
--                               (post-mortem encounter, or a wrong death date)
--   death_before_t0             death_day precedes time zero
-- ============================================================================
CREATE TABLE pcx__warn_outcome_vital_status_conflict AS

SELECT  'death_day_disagree'                                                    AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('fhir=',     CAST(fhir_death_day AS VARCHAR)),
            CONCAT('llm=',      CAST(llm_death_day AS VARCHAR)),
            CONCAT('days=',     CAST(DATE_DIFF('day', fhir_death_day, llm_death_day) AS VARCHAR)))
                                                                                AS detail
FROM    pcx__outcome_vital_status
WHERE   fhir_death_day IS NOT NULL
AND     llm_death_day IS NOT NULL
AND     fhir_death_day <> llm_death_day

UNION ALL

SELECT  'deceased_without_death_day'                                            AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('fhir_flag=',        CAST(fhir_deceased_bool AS VARCHAR)),
            CONCAT('llm_flag=',         CAST(llm_deceased_bool AS VARCHAR)),
            CONCAT('last_alive=',       CAST(last_known_alive_day AS VARCHAR)))
                                                                                AS detail
FROM    pcx__outcome_vital_status
WHERE   deceased_bool
AND     death_day IS NULL

UNION ALL

SELECT  'alive_after_death'                                                     AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('death=',            CAST(death_day AS VARCHAR)),
            CONCAT('last_alive=',       CAST(last_known_alive_day AS VARCHAR)),
            CONCAT('last_encounter=',   CAST(last_encounter_day AS VARCHAR)),
            CONCAT('llm_last_alive=',   CAST(llm_last_known_alive_day AS VARCHAR)),
            CONCAT('days=',             CAST(DATE_DIFF('day', death_day, last_known_alive_day) AS VARCHAR)))
                                                                                AS detail
FROM    pcx__outcome_vital_status
WHERE   death_day IS NOT NULL
AND     last_known_alive_day > death_day

UNION ALL

SELECT  'death_before_t0'                                                       AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('death=',    CAST(death_day AS VARCHAR)),
            CONCAT('t0=',       CAST(t0_day AS VARCHAR)),
            CONCAT('days=',     CAST(DATE_DIFF('day', death_day, t0_day) AS VARCHAR)))
                                                                                AS detail
FROM    pcx__outcome_vital_status
WHERE   death_day IS NOT NULL
AND     t0_day IS NOT NULL
AND     death_day < t0_day
;
