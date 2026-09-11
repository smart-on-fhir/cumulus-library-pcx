-- ============================================================================
-- Warning: definitive surgery evidence is missing, ambiguous, or undated.
--
--   surgery_missing            subject has a t0_day but no definitive surgery
--                              day from either source, so the ACNS0334 age
--                              criterion is NULL and the subject leaves the
--                              trial-like cohort
--   surgery_multiple_tier1     more than one structured tier 1 resection and no
--                              LLM definitive designation, so MIN() picked one
--   surgery_undated_tier1      tier 1 resection procedures exist but none has a
--                              performed day, so the structured fallback is NULL
--   surgery_llm_without_role   LLM surgeries documented, none tagged definitive
-- ============================================================================
CREATE TABLE pcx__warn_eligible_surgery_evidence AS

WITH structured_all AS (
    SELECT  subject_ref,
            COUNT(DISTINCT procedure_ref)                                       AS proc_cnt,
            COUNT(DISTINCT CASE WHEN proc_performed_day IS NOT NULL THEN procedure_ref END)
                                                                                AS proc_dated_cnt
    FROM    pcx__cohort_proc_craniotomy
    WHERE   tier = 1
    GROUP BY subject_ref
)

SELECT  'surgery_missing'                                                       AS warn_check,
        CAST(surgery.subject_ref AS VARCHAR)                                    AS subject_ref,
        CONCAT_WS('|',
            CONCAT('t0=',               CAST(dx.t0_day AS VARCHAR)),
            CONCAT('llm_first=',        CAST(surgery.llm_surgery_first_day AS VARCHAR)),
            CONCAT('tier1_cnt=',        CAST(COALESCE(surgery.proc_craniotomy_tier1_cnt, 0) AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_surgery   AS surgery
JOIN    pcx__eligible_dx        AS dx ON dx.subject_ref = surgery.subject_ref
WHERE   dx.t0_day IS NOT NULL
AND     surgery.definitive_surgery_day IS NULL

UNION ALL

SELECT  'surgery_multiple_tier1'                                                AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('tier1_cnt=',        CAST(proc_craniotomy_tier1_cnt AS VARCHAR)),
            CONCAT('first=',            CAST(proc_craniotomy_tier1_first_day AS VARCHAR)),
            CONCAT('source=',           definitive_surgery_source))             AS detail
FROM    pcx__eligible_surgery
WHERE   proc_craniotomy_tier1_cnt > 1
AND     llm_definitive_surgery_day IS NULL

UNION ALL

SELECT  'surgery_undated_tier1'                                                 AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('tier1_cnt=',        CAST(proc_cnt AS VARCHAR)),
            CONCAT('dated_cnt=',        CAST(proc_dated_cnt AS VARCHAR)))       AS detail
FROM    structured_all
WHERE   proc_dated_cnt < proc_cnt

UNION ALL

SELECT  'surgery_llm_without_role'                                              AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('llm_first=',        CAST(llm_surgery_first_day AS VARCHAR)),
            CONCAT('structured=',       CAST(proc_craniotomy_tier1_first_day AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_surgery
WHERE   llm_surgery_first_day IS NOT NULL
AND     llm_definitive_surgery_day IS NULL
;
