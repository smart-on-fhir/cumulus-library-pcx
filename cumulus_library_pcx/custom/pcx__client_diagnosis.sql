-- ==========================================================================
-- Grain: one row per subject_ref.
--
-- Diagnosis phenotype from the LLM chart-review tasks, resolved two ways:
--   _baseline  documentation within 90 days either side of t0_day, the
--              diagnosis-time reading that is safe as a causal covariate
--   _ever      any note, carries later reclassification and progression
-- Note dates come from the shared author spine, never re-derived here.
-- Subtype and histology resolve to the LATEST documented real value, because
-- a later pathology or methylation report supersedes an earlier one.
-- Chang M-stage resolves to the MOST SEVERE documented value, because staging
-- is cumulative. Conflicts are counted rather than hidden.
-- ==========================================================================
CREATE TABLE pcx__client_diagnosis AS
WITH
diagnosis_note AS (
    SELECT  src.subject_ref,
            src.note_ref,
            note_day.note_author_date,
            (ABS(DATE_DIFF('day', elig.t0_day, note_day.note_author_date)) <= 90)
                                                        AS in_baseline,
            src.disease_subtype,
            src.medulloblastoma_histology,
            src.historical_diagnosis_term,
            src.tumor_location_verbatim,
            src.chang_m_stage,
            CASE src.chang_m_stage
                WHEN 'M0' THEN 0
                WHEN 'M1' THEN 1
                WHEN 'M2' THEN 2
                WHEN 'M3' THEN 3
                WHEN 'M4' THEN 4
                ELSE -1
            END                                         AS m_stage_rank,
            src.age_at_diagnosis_months
    FROM    pcx__llm_diagnosis_wide     AS src
    JOIN    pcx__sample_casedef_author  AS note_day
      ON    src.subject_ref = note_day.subject_ref
     AND    src.note_ref    = note_day.note_ref
    JOIN    pcx__eligible               AS elig
      ON    src.subject_ref = elig.subject_ref
),

diagnosis AS (
    SELECT  subject_ref,
            COUNT(DISTINCT note_ref)                                    AS diagnosis_note_count,
            -- latest real subtype
            MAX_BY(disease_subtype, ROW(note_author_date, note_ref))
                FILTER (WHERE disease_subtype <> 'NONE_OF_THE_ABOVE')   AS disease_subtype_ever,
            MAX_BY(disease_subtype, ROW(note_author_date, note_ref))
                FILTER (WHERE disease_subtype <> 'NONE_OF_THE_ABOVE' AND in_baseline)
                                                                        AS disease_subtype_baseline,
            COUNT(DISTINCT disease_subtype)
                FILTER (WHERE disease_subtype <> 'NONE_OF_THE_ABOVE')   AS disease_subtype_distinct_count,
            BOOL_OR(disease_subtype = 'MEDULLOBLASTOMA')                AS medulloblastoma_ever_bool,
            BOOL_OR(disease_subtype = 'ATRT')                           AS atrt_ever_bool,
            -- latest real histology
            MAX_BY(medulloblastoma_histology, ROW(note_author_date, note_ref))
                FILTER (WHERE medulloblastoma_histology <> 'NONE_OF_THE_ABOVE')
                                                                        AS histology_ever,
            MAX_BY(medulloblastoma_histology, ROW(note_author_date, note_ref))
                FILTER (WHERE medulloblastoma_histology <> 'NONE_OF_THE_ABOVE' AND in_baseline)
                                                                        AS histology_baseline,
            BOOL_OR(medulloblastoma_histology = 'LARGE_CELL_ANAPLASTIC') AS anaplastic_ever_bool,
            -- most severe documented M-stage
            MAX_BY(chang_m_stage, m_stage_rank)
                FILTER (WHERE m_stage_rank >= 0)                        AS chang_m_stage_ever,
            MAX_BY(chang_m_stage, m_stage_rank)
                FILTER (WHERE m_stage_rank >= 0 AND in_baseline)        AS chang_m_stage_baseline,
            BOOL_OR(m_stage_rank >= 1)                                  AS metastatic_ever_bool,
            -- verbatim wording, latest
            MAX_BY(historical_diagnosis_term, ROW(note_author_date, note_ref))
                FILTER (WHERE historical_diagnosis_term IS NOT NULL)    AS historical_diagnosis_term,
            MAX_BY(tumor_location_verbatim, ROW(note_author_date, note_ref))
                FILTER (WHERE tumor_location_verbatim IS NOT NULL)      AS tumor_location_verbatim,
            MIN(age_at_diagnosis_months)                                AS age_at_diagnosis_months_stated
    FROM    diagnosis_note
    GROUP BY subject_ref
),

-- Molecular group from the compact medulloblastoma task. A clinical-summary
-- mention is not methylation confirmation, so the method rides along.
molecular_note AS (
    SELECT  src.subject_ref,
            src.note_ref,
            note_day.note_author_date,
            (ABS(DATE_DIFF('day', elig.t0_day, note_day.note_author_date)) <= 90)
                                                        AS in_baseline,
            src.molecular_group,
            src.molecular_group_classification_method
    FROM    pcx__llm_medulloblastoma_wide   AS src
    JOIN    pcx__sample_casedef_author      AS note_day
      ON    src.subject_ref = note_day.subject_ref
     AND    src.note_ref    = note_day.note_ref
    JOIN    pcx__eligible                   AS elig
      ON    src.subject_ref = elig.subject_ref
    WHERE   src.molecular_group <> 'NONE_OF_THE_ABOVE'
),

molecular AS (
    SELECT  subject_ref,
            MAX_BY(molecular_group, ROW(note_author_date, note_ref))    AS molecular_group_ever,
            MAX_BY(molecular_group, ROW(note_author_date, note_ref))
                FILTER (WHERE in_baseline)                              AS molecular_group_baseline,
            MAX_BY(molecular_group_classification_method, ROW(note_author_date, note_ref))
                FILTER (WHERE molecular_group_classification_method IS NOT NULL)
                                                                        AS molecular_group_method,
            COUNT(DISTINCT molecular_group)
                FILTER (WHERE molecular_group <> 'CONFLICTING')         AS molecular_group_distinct_count,
            BOOL_OR(molecular_group = 'GROUP_3')                        AS group_3_ever_bool
    FROM    molecular_note
    GROUP BY subject_ref
),

-- Structured case-definition subtypes at tier 1, for comparison with the notes.
casedef AS (
    SELECT  subject_ref,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(DISTINCT subtype)), '|')    AS casedef_subtypes_tier1
    FROM    pcx__cohort_casedef
    WHERE   tier = 1
    GROUP BY subject_ref
)

SELECT  elig.subject_ref,
        elig.t0_day,
        casedef.casedef_subtypes_tier1,
        elig.medulloblastoma_tier1_bool,
        dx.atrt_tier1_bool,
        diagnosis.diagnosis_note_count,
        diagnosis.disease_subtype_ever,
        diagnosis.disease_subtype_baseline,
        diagnosis.disease_subtype_distinct_count,
        diagnosis.medulloblastoma_ever_bool,
        diagnosis.atrt_ever_bool,
        diagnosis.histology_ever,
        diagnosis.histology_baseline,
        diagnosis.anaplastic_ever_bool,
        diagnosis.chang_m_stage_ever,
        diagnosis.chang_m_stage_baseline,
        diagnosis.metastatic_ever_bool,
        diagnosis.historical_diagnosis_term,
        diagnosis.tumor_location_verbatim,
        diagnosis.age_at_diagnosis_months_stated,
        dx.llm_diagnosis_day_min                        AS diagnosis_day_stated_min,
        dx.llm_diagnosis_gold_day_min                   AS diagnosis_gold_day_min,
        dx.llm_age_months_at_diagnosis_gold             AS age_months_at_diagnosis_gold,
        molecular.molecular_group_ever,
        molecular.molecular_group_baseline,
        molecular.molecular_group_method,
        molecular.molecular_group_distinct_count,
        molecular.group_3_ever_bool
FROM    pcx__eligible           AS elig
JOIN    pcx__eligible_dx        AS dx           ON dx.subject_ref        = elig.subject_ref
LEFT JOIN casedef                               ON casedef.subject_ref   = elig.subject_ref
LEFT JOIN diagnosis                             ON diagnosis.subject_ref = elig.subject_ref
LEFT JOIN molecular                             ON molecular.subject_ref = elig.subject_ref
;
