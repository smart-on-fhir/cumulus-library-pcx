-- ============================================================================
-- Warning: LLM diagnosis is more than 90 days BEFORE the structured time zero.
--
-- llm_day is the earliest LLM tissue-diagnosis date (diagnosis_date_gold),
-- falling back to the earliest LLM diagnosis_date. A note-stated diagnosis
-- well before t0_day usually means an outside diagnosis (transfer-in) or a
-- casedef valueset gap, so age_months_at_t0 and every prior-to-t0 flag are
-- measured from the wrong day.
-- Companion: pcx__warn_eligible_dx_date_disagree_fhir_before_llm.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_dx_date_disagree_llm_before_fhir AS

WITH disagreement AS (
    SELECT  subject_ref,
            t0_day                                                      AS fhir_day,
            COALESCE(llm_diagnosis_gold_day_min, llm_diagnosis_day_min) AS llm_day
    FROM    pcx__eligible_dx
)

SELECT  'dx_date_llm_before_fhir'                                               AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('llm=',      CAST(llm_day AS VARCHAR)),
            CONCAT('fhir=',     CAST(fhir_day AS VARCHAR)),
            CONCAT('days=',     CAST(DATE_DIFF('day', llm_day, fhir_day) AS VARCHAR)))
                                                                                AS detail
FROM    disagreement
WHERE   fhir_day IS NOT NULL
AND     llm_day IS NOT NULL
AND     DATE_DIFF('day', llm_day, fhir_day) > 90
;
