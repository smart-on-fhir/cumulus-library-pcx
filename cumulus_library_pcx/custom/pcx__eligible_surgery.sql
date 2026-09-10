--  =====================================================================
--  Eligibility: definitive surgery
--
--  ACNS0334 anchors age on the date of DEFINITIVE surgery. Two sources:
--    structured  pcx__cohort_proc_craniotomy (tier 1 tumor resection codes)
--    LLM         pcx__llm_surgery_wide (surgery_role names the definitive operation)
--  definitive_surgery_day prefers the LLM-designated definitive operation and
--  falls back to the first structured tier 1 resection. Both inputs stay
--  visible as their own columns so the choice can be audited.
--  =====================================================================
CREATE  TABLE   pcx__eligible_surgery AS
WITH
structured AS (
    SELECT  subject_ref,
            MIN(proc_performed_day)                                     AS proc_craniotomy_tier1_first_day,
            COUNT(DISTINCT procedure_ref)                               AS proc_craniotomy_tier1_cnt
    FROM    pcx__cohort_proc_craniotomy
    WHERE   tier = 1
    GROUP BY subject_ref
),
llm AS (
    SELECT  subject_ref,
            MIN(CAST(surgery_date AS DATE))                             AS llm_surgery_first_day,
            MIN(CASE WHEN LOWER(surgery_role) LIKE '%definitive%'
                     THEN CAST(surgery_date AS DATE) END)               AS llm_definitive_surgery_day,
            MIN(CASE WHEN LOWER(surgery_role) LIKE '%definitive%'
                     THEN age_at_surgery_months END)                    AS llm_age_at_definitive_surgery_months,
            MIN(residual_tumor_area_cm2)                                AS llm_residual_tumor_area_cm2_min,
            MAX(residual_tumor_area_cm2)                                AS llm_residual_tumor_area_cm2_max,
            BOOL_OR(extent_of_resection IN ('PARTIAL_RESECTION', 'BIOPSY')) AS llm_residual_disease_bool
    FROM    pcx__llm_surgery_wide
    WHERE   surgery_type <> 'NONE_OF_THE_ABOVE'
    GROUP BY subject_ref
),
combined AS (
    SELECT  dx.subject_ref,
            dx.birthdate,
            -- precedence: LLM definitive operation, then first structured tier 1 resection
            COALESCE(llm.llm_definitive_surgery_day, structured.proc_craniotomy_tier1_first_day)
                                                                        AS definitive_surgery_day,
            CASE
                WHEN llm.llm_definitive_surgery_day IS NOT NULL         THEN 'llm_surgery_role_definitive'
                WHEN structured.proc_craniotomy_tier1_first_day IS NOT NULL THEN 'proc_craniotomy_tier1_first'
            END                                                         AS definitive_surgery_source,
            structured.proc_craniotomy_tier1_first_day,
            structured.proc_craniotomy_tier1_cnt,
            llm.llm_surgery_first_day,
            llm.llm_definitive_surgery_day,
            llm.llm_age_at_definitive_surgery_months,
            llm.llm_residual_tumor_area_cm2_min,
            llm.llm_residual_tumor_area_cm2_max,
            llm.llm_residual_disease_bool
    FROM    pcx__eligible_dx   AS dx
    LEFT JOIN structured                ON structured.subject_ref = dx.subject_ref
    LEFT JOIN llm                       ON llm.subject_ref        = dx.subject_ref
)
SELECT  combined.*,
        DATE_DIFF('month', birthdate, definitive_surgery_day)           AS age_months_at_definitive_surgery,
        (DATE_DIFF('month', birthdate, definitive_surgery_day) < 36)    AS age_under_36_months_at_definitive_surgery
FROM    combined
;