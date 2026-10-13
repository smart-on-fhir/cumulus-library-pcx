-- ============================================================================
-- Warning: note-stated age disagrees with birthdate arithmetic.
--
--   age_at_diagnosis_disagree   LLM age_at_diagnosis_months (minimum across
--                               notes) vs DATE_DIFF months from birthdate to
--                               t0_day, more than 3 months apart
--   age_at_surgery_disagree     LLM age at the definitive operation vs months
--                               from birthdate to definitive_surgery_day
--
-- Either side can be wrong: a bad birthdate, a t0_day that lags diagnosis, or
-- an LLM reading an age from the wrong sentence. Both anchors are shown.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_age_disagree AS

SELECT  'age_at_diagnosis_disagree'                                             AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('computed_t0=',      CAST(age_months_at_t0 AS VARCHAR)),
            CONCAT('llm=',              CAST(llm_age_at_diagnosis_months_min AS VARCHAR)),
            CONCAT('computed_llm_gold=',CAST(llm_age_months_at_diagnosis_gold AS VARCHAR)),
            CONCAT('t0=',               CAST(t0_day AS VARCHAR)))               AS detail
FROM    pcx__eligible_dx
WHERE   age_months_at_t0 IS NOT NULL
AND     llm_age_at_diagnosis_months_min IS NOT NULL
AND     ABS(age_months_at_t0 - llm_age_at_diagnosis_months_min) > 3

UNION ALL

SELECT  'age_at_surgery_disagree'                                               AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('computed=',     CAST(age_months_at_definitive_surgery AS VARCHAR)),
            CONCAT('llm=',          CAST(llm_age_at_definitive_surgery_months AS VARCHAR)),
            CONCAT('surgery=',      CAST(definitive_surgery_day AS VARCHAR)),
            CONCAT('source=',       definitive_surgery_source))                 AS detail
FROM    pcx__eligible_surgery
WHERE   age_months_at_definitive_surgery IS NOT NULL
AND     llm_age_at_definitive_surgery_months IS NOT NULL
AND     ABS(age_months_at_definitive_surgery - llm_age_at_definitive_surgery_months) > 3
;
