-- ============================================================================
-- Warning: definitive surgery day is hard to reconcile.
--
--   surgery_llm_vs_structured_disagree   LLM-designated definitive operation
--                                        and first structured tier 1 resection
--                                        more than 14 days apart
--   surgery_long_before_t0               definitive surgery more than 60 days
--                                        before t0_day (outside surgery, or t0
--                                        lags the diagnosis)
--   surgery_long_after_t0                definitive surgery more than 180 days
--                                        after t0_day (second-look or salvage
--                                        operation mislabelled as definitive)
--
-- definitive_surgery_day drives age_under_36_months_at_definitive_surgery,
-- the ACNS0334 age criterion, so every one of these moves trial membership.
-- surgery_role is free text matched with LIKE '%definitive%'.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_surgery_timing AS

WITH surgery AS (
    SELECT  surgery.subject_ref,
            dx.t0_day,
            surgery.definitive_surgery_day,
            surgery.definitive_surgery_source,
            surgery.llm_definitive_surgery_day,
            surgery.proc_craniotomy_tier1_first_day
    FROM    pcx__eligible_surgery   AS surgery
    JOIN    pcx__eligible_dx        AS dx ON dx.subject_ref = surgery.subject_ref
)

SELECT  'surgery_llm_vs_structured_disagree'                                    AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('llm=',          CAST(llm_definitive_surgery_day AS VARCHAR)),
            CONCAT('structured=',   CAST(proc_craniotomy_tier1_first_day AS VARCHAR)),
            CONCAT('days=',         CAST(DATE_DIFF('day', proc_craniotomy_tier1_first_day, llm_definitive_surgery_day) AS VARCHAR)))
                                                                                AS detail
FROM    surgery
WHERE   llm_definitive_surgery_day IS NOT NULL
AND     proc_craniotomy_tier1_first_day IS NOT NULL
AND     ABS(DATE_DIFF('day', proc_craniotomy_tier1_first_day, llm_definitive_surgery_day)) > 14

UNION ALL

SELECT  'surgery_long_before_t0'                                                AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('surgery=',      CAST(definitive_surgery_day AS VARCHAR)),
            CONCAT('t0=',           CAST(t0_day AS VARCHAR)),
            CONCAT('days=',         CAST(DATE_DIFF('day', definitive_surgery_day, t0_day) AS VARCHAR)),
            CONCAT('source=',       definitive_surgery_source))                 AS detail
FROM    surgery
WHERE   definitive_surgery_day IS NOT NULL
AND     t0_day IS NOT NULL
AND     DATE_DIFF('day', definitive_surgery_day, t0_day) > 60

UNION ALL

SELECT  'surgery_long_after_t0'                                                 AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('surgery=',      CAST(definitive_surgery_day AS VARCHAR)),
            CONCAT('t0=',           CAST(t0_day AS VARCHAR)),
            CONCAT('days=',         CAST(DATE_DIFF('day', t0_day, definitive_surgery_day) AS VARCHAR)),
            CONCAT('source=',       definitive_surgery_source))                 AS detail
FROM    surgery
WHERE   definitive_surgery_day IS NOT NULL
AND     t0_day IS NOT NULL
AND     DATE_DIFF('day', t0_day, definitive_surgery_day) > 180
;
