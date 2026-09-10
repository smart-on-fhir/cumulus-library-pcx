--  =====================================================================
--  Eligibility: diagnosis
--
--  One row per case-definition subject. Time zero (t0_day) is the first
--  study-population encounter carrying a TIER 1 medulloblastoma casedef code.
--  Tier 2 and 3 codes (unspecified brain neoplasm) are kept as evidence only,
--  so a subject with no tier 1 code has a NULL t0_day and stays a candidate.
--  Age is in completed months from core__patient.birthdate, because the
--  ACNS0334 criterion is under 36 months and integer years cannot express it.
--  LLM diagnosis evidence comes from pcx__llm_diagnosis_wide and is
--  reported beside the structured evidence, never merged into it.
--  =====================================================================
CREATE  TABLE   pcx__eligible_dx AS
WITH
casedef_subject AS (
    SELECT  DISTINCT subject_ref
    FROM    pcx__cohort_casedef
    WHERE   subtype IS NOT NULL
),
casedef_tier1 AS (
    SELECT  subject_ref,
            subtype,
            MIN(enc_period_start_day)   AS first_day
    FROM    pcx__cohort_casedef
    WHERE   tier = 1
    GROUP BY subject_ref, subtype
),
medulloblastoma_tier1 AS (
    SELECT  subject_ref, first_day AS t0_day
    FROM    casedef_tier1
    WHERE   subtype = 'medulloblastoma'
),
atrt_tier1 AS (
    SELECT  subject_ref, first_day AS atrt_first_day
    FROM    casedef_tier1
    WHERE   subtype = 'atrt'
),
llm_diagnosis AS (
    SELECT  subject_ref,
            BOOL_OR(disease_subtype = 'MEDULLOBLASTOMA')            AS llm_medulloblastoma_bool,
            BOOL_OR(disease_subtype = 'ATRT')                       AS llm_atrt_bool,
            MIN(CAST(diagnosis_date AS DATE))                       AS llm_diagnosis_day_min,
            MIN(CAST(diagnosis_date_gold AS DATE))                  AS llm_diagnosis_gold_day_min,
            MIN(age_at_diagnosis_months)                            AS llm_age_at_diagnosis_months_min,
            BOOL_OR(chang_m_stage IN ('M1', 'M2', 'M3', 'M4'))      AS llm_metastatic_bool,
            BOOL_OR(medulloblastoma_histology = 'LARGE_CELL_ANAPLASTIC') AS llm_anaplastic_bool
    FROM    pcx__llm_diagnosis_wide
    GROUP BY subject_ref
)
SELECT  subj.subject_ref,
        pat.birthdate,
        pat.gender,
        mb.t0_day,
        'casedef_tier1_medulloblastoma'                             AS t0_source,
        DATE_DIFF('month', pat.birthdate, mb.t0_day)                AS age_months_at_t0,
        (DATE_DIFF('month', pat.birthdate, mb.t0_day) < 36)         AS age_under_36_months_at_t0,
        (mb.subject_ref IS NOT NULL)                                AS medulloblastoma_tier1_bool,
        (atrt.subject_ref IS NOT NULL)                              AS atrt_tier1_bool,
        atrt.atrt_first_day,
        llm.llm_medulloblastoma_bool,
        llm.llm_atrt_bool,
        llm.llm_diagnosis_day_min,
        llm.llm_diagnosis_gold_day_min,
        DATE_DIFF('month', pat.birthdate, llm.llm_diagnosis_gold_day_min)
                                                                    AS llm_age_months_at_diagnosis_gold,
        llm.llm_age_at_diagnosis_months_min,
        llm.llm_metastatic_bool,
        llm.llm_anaplastic_bool
FROM    casedef_subject         AS subj
JOIN    core__patient           AS pat  ON pat.subject_ref  = subj.subject_ref
LEFT JOIN medulloblastoma_tier1 AS mb   ON mb.subject_ref   = subj.subject_ref
LEFT JOIN atrt_tier1            AS atrt ON atrt.subject_ref = subj.subject_ref
LEFT JOIN llm_diagnosis         AS llm  ON llm.subject_ref  = subj.subject_ref
;