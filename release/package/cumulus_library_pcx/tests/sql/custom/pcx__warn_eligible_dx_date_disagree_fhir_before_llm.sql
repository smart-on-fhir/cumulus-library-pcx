-- ============================================================================
-- Warning: structured time zero is more than 90 days BEFORE the LLM diagnosis.
--
-- llm_day is the earliest LLM tissue-diagnosis date (diagnosis_date_gold),
-- falling back to the earliest LLM diagnosis_date. A structured t0_day well
-- before any note-stated diagnosis suggests the tier 1 code was attached to a
-- pre-diagnosis encounter (imaging, admission) or belongs to another tumor.
-- Companion: pcx__warn_eligible_dx_date_disagree_llm_before_fhir.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_dx_date_disagree_fhir_before_llm AS

WITH disagreement AS (
    SELECT  subject_ref,
            t0_day                                                      AS fhir_day,
            COALESCE(llm_diagnosis_gold_day_min, llm_diagnosis_day_min) AS llm_day
    FROM    pcx__eligible_dx
)

SELECT  'dx_date_fhir_before_llm'                                               AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('fhir=',     CAST(fhir_day AS VARCHAR)),
            CONCAT('llm=',      CAST(llm_day AS VARCHAR)),
            CONCAT('days=',     CAST(DATE_DIFF('day', fhir_day, llm_day) AS VARCHAR)))
                                                                                AS detail
FROM    disagreement
WHERE   fhir_day IS NOT NULL
AND     llm_day IS NOT NULL
AND     DATE_DIFF('day', fhir_day, llm_day) > 90
;
