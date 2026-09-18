--  =====================================================================
--  Eligibility: definitive surgery
--
--  ACNS0334 anchors age on the date of DEFINITIVE surgery. Two sources:
--    structured  pcx__cohort_proc_craniotomy (tier 1 tumor resection codes)
--    LLM         pcx__llm_surgery_wide (extent_of_resection names a resection)
--  An LLM operation counts as a resection when extent_of_resection is
--  GROSS_TOTAL, NEAR_TOTAL or PARTIAL. BIOPSY and NONE_OF_THE_ABOVE rows are
--  still documented operations (they feed llm_surgery_first_day and the
--  residual-disease flag) but never pick the definitive day.
--  definitive_surgery_day prefers the earliest LLM resection and falls back
--  to the first structured tier 1 resection. Both inputs stay visible as
--  their own columns so the choice can be audited.
--  =====================================================================
CREATE  TABLE   pcx__eligible_surgery AS
WITH
structured AS (
    SELECT  subject_ref,
            MIN(proc_performed_day)                                     AS proc_craniotomy_tier1_first_day,
            COUNT(DISTINCT procedure_ref)                               AS proc_craniotomy_tier1_cnt
    FROM    pcx__cohort_proc_craniotomy
    WHERE   CAST(tier AS INTEGER) = 1
    GROUP BY subject_ref
),
llm AS (
    SELECT  subject_ref,
            MIN(CAST(surgery_date AS DATE))                             AS llm_surgery_first_day,
            MIN(CASE WHEN extent_of_resection IN ('GROSS_TOTAL_RESECTION', 'NEAR_TOTAL_RESECTION', 'PARTIAL_RESECTION')
                     THEN CAST(surgery_date AS DATE) END)               AS llm_definitive_surgery_day,
            MIN(CASE WHEN extent_of_resection IN ('GROSS_TOTAL_RESECTION', 'NEAR_TOTAL_RESECTION', 'PARTIAL_RESECTION')
                     THEN age_at_surgery_months END)                    AS llm_age_at_definitive_surgery_months,
            MIN(residual_tumor_area_cm2)                                AS llm_residual_tumor_area_cm2_min,
            MAX(residual_tumor_area_cm2)                                AS llm_residual_tumor_area_cm2_max,
            BOOL_OR(extent_of_resection IN ('PARTIAL_RESECTION', 'BIOPSY')) AS llm_residual_disease_bool
    FROM    pcx__llm_surgery_wide
    GROUP BY subject_ref
),
combined AS (
    SELECT  dx.subject_ref,
            dx.birthdate,
            -- precedence: earliest LLM resection, then first structured tier 1 resection
            COALESCE(llm.llm_definitive_surgery_day, structured.proc_craniotomy_tier1_first_day)
                                                                        AS definitive_surgery_day,
            CASE
                WHEN llm.llm_definitive_surgery_day IS NOT NULL         THEN 'llm_surgery_resection'
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