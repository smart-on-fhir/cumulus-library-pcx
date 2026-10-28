--  =====================================================================
--  Eligibility: diagnosis
--
--  One row per case-definition subject. Time zero (t0_day) is, in order:
--    1. llm_diagnosis_gold: the earliest day-precision confirmatory tissue
--       diagnosis date (diagnosis_date_gold) from a diagnosis-task note naming
--       any embryonal subtype, ATRT included (ATRT is excluded downstream).
--       The gold standard, preferred over coded entries.
--    2. casedef_tier1_medulloblastoma: the first study-population encounter
--       carrying a TIER 1 medulloblastoma casedef code.
--  Month or year precision gold dates do not set t0. Tier 2 codes (CHOP roster,
--  unspecified brain neoplasm) are evidence only, so a subject with neither
--  source has a NULL t0_day and t0_source and stays a candidate.
--  Age is in completed months from core__patient.birthdate, not from
--  core__encounter.age_at_visit (whole years). Under 36 months alone would
--  equal age_at_visit < 3, but age_months_at_t0, the under-8-months
--  high-risk qualifier (pcx__eligible) and the LLM diagnosis-gold age
--  (not an encounter day) all need months.
--  LLM diagnosis evidence comes from pcx__llm_diagnosis_wide and is
--  reported beside the structured evidence, never merged into it.
--  ATRT is an ACNS0334 exclusion, not a case. Its casedef rows exist only so
--  the exclusion can be evaluated and a medulloblastoma later reclassified
--  as ATRT stays visible (atrt_tier1_bool). A subject whose ONLY casedef
--  evidence is ATRT is therefore not a case-definition subject here.
--  =====================================================================
CREATE  TABLE   pcx__eligible_dx AS
WITH
casedef_subject AS (
    SELECT  DISTINCT subject_ref
    FROM    pcx__cohort_casedef
    WHERE   subtype IS NOT NULL
    AND     subtype <> 'atrt'
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
            MIN(diagnosis_day)                                      AS llm_diagnosis_day_min,
            MIN(diagnosis_gold_day)                                 AS llm_diagnosis_gold_day_min,
            MIN(diagnosis_gold_day) FILTER (
                WHERE diagnosis_gold_day_precision = 'DAY'
                AND   disease_subtype <> 'NONE_OF_THE_ABOVE')       AS llm_t0_gold_day,
            MIN(age_at_diagnosis_months)                            AS llm_age_at_diagnosis_months_min,
            BOOL_OR(chang_m_stage IN ('M1', 'M2', 'M3', 'M4'))      AS llm_metastatic_bool,
            BOOL_OR(medulloblastoma_histology = 'LARGE_CELL_ANAPLASTIC') AS llm_anaplastic_bool
    FROM    pcx__llm_diagnosis_wide
    GROUP BY subject_ref
),
subject_t0 AS (
    SELECT  subj.subject_ref,
            COALESCE(llm.llm_t0_gold_day, mb.t0_day)                AS t0_day,
            CASE
                WHEN llm.llm_t0_gold_day IS NOT NULL
                THEN 'llm_diagnosis_gold'
                WHEN mb.t0_day IS NOT NULL
                THEN 'casedef_tier1_medulloblastoma'
            END                                                     AS t0_source,
            mb.t0_day                                               AS casedef_t0_day
    FROM    casedef_subject         AS subj
    LEFT JOIN medulloblastoma_tier1 AS mb   ON mb.subject_ref   = subj.subject_ref
    LEFT JOIN llm_diagnosis         AS llm  ON llm.subject_ref  = subj.subject_ref
)
SELECT  subj.subject_ref,
        pat.birthdate,
        pat.gender,
        t0.t0_day,
        t0.t0_source,
        t0.casedef_t0_day,
        llm.llm_t0_gold_day,
        DATE_DIFF('month', pat.birthdate, t0.t0_day)                AS age_months_at_t0,
        (DATE_DIFF('month', pat.birthdate, t0.t0_day) < 36)         AS age_under_36_months_at_t0,
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
JOIN    subject_t0              AS t0   ON t0.subject_ref   = subj.subject_ref
LEFT JOIN medulloblastoma_tier1 AS mb   ON mb.subject_ref   = subj.subject_ref
LEFT JOIN atrt_tier1            AS atrt ON atrt.subject_ref = subj.subject_ref
LEFT JOIN llm_diagnosis         AS llm  ON llm.subject_ref  = subj.subject_ref
;