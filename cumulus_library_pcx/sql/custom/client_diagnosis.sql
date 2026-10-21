-- ==========================================================================
-- Grain: one row per subject_ref.
--
-- Diagnosis phenotype from the LLM chart-review tasks, resolved two ways:
--   _baseline  documentation within 90 days either side of t0_day, the
--              diagnosis-time reading that is safe as a causal covariate
--   _ever      any note, carries later reclassification and progression
-- Note dates come from pcx__llm_note_date, one per selected note (casedef and
-- Elasticsearch notes), never re-derived here. A note without a usable date
-- still counts in the _ever, count and conflict columns. It is never baseline,
-- and it is the latest only when no dated note has a value: note_order_day
-- sorts it before every dated note.
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
            COALESCE(note_day.note_date, DATE '0001-01-01')    AS note_order_day,
            (ABS(DATE_DIFF('day', elig.t0_day, note_day.note_date)) <= 90)
                                                        AS in_baseline,
            src.disease_subtype,
            src.medulloblastoma_histology,
            src.historical_diagnosis_term,
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
    LEFT JOIN pcx__llm_note_date    AS note_day
      ON    src.subject_ref = note_day.subject_ref
     AND    src.note_ref    = note_day.note_ref
    JOIN    pcx__eligible               AS elig
      ON    src.subject_ref = elig.subject_ref
),

diagnosis AS (
    SELECT  subject_ref,
            COUNT(DISTINCT note_ref)                                    AS diagnosis_note_count,
            -- latest real subtype
            MAX_BY(disease_subtype, ROW(note_order_day, note_ref))
                FILTER (WHERE disease_subtype <> 'NONE_OF_THE_ABOVE')   AS disease_subtype_ever,
            MAX_BY(disease_subtype, ROW(note_order_day, note_ref))
                FILTER (WHERE disease_subtype <> 'NONE_OF_THE_ABOVE' AND in_baseline)
                                                                        AS disease_subtype_baseline,
            COUNT(DISTINCT disease_subtype)
                FILTER (WHERE disease_subtype <> 'NONE_OF_THE_ABOVE')   AS disease_subtype_distinct_count,
            BOOL_OR(disease_subtype = 'MEDULLOBLASTOMA')                AS medulloblastoma_ever_bool,
            BOOL_OR(disease_subtype = 'ATRT')                           AS atrt_ever_bool,
            -- latest real histology
            MAX_BY(medulloblastoma_histology, ROW(note_order_day, note_ref))
                FILTER (WHERE medulloblastoma_histology <> 'NONE_OF_THE_ABOVE')
                                                                        AS histology_ever,
            MAX_BY(medulloblastoma_histology, ROW(note_order_day, note_ref))
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
            MAX_BY(historical_diagnosis_term, ROW(note_order_day, note_ref))
                FILTER (WHERE historical_diagnosis_term IS NOT NULL)    AS historical_diagnosis_term,
            MIN(age_at_diagnosis_months)                                AS age_at_diagnosis_months_stated
    FROM    diagnosis_note
    GROUP BY subject_ref
),

-- Molecular group from the molecular task, one row per documented report.
-- One report is selected per subject, and its group and methods are reported
-- together, so the method always describes the selected group. A CLINICAL_SUMMARY
-- method is not methylation confirmation. Report order:
--   1. a real group (WNT, SHH, GROUP_3, GROUP_4, NON_WNT_NON_SHH) beats
--      NOT_SUBGROUPED and INDETERMINATE, which are absence of a result. Those
--      are reported only when the subject has no real group.
--   2. the latest note, undated notes first
--   3. the last report in the note
molecular_note AS (
    SELECT  DISTINCT
            src.subject_ref,
            CONCAT(src.note_ref, '#', CAST(src.report_index AS VARCHAR))   AS report_key,
            ROW(src.molecular_group NOT IN ('NOT_SUBGROUPED', 'INDETERMINATE'),
                COALESCE(note_day.note_date, DATE '0001-01-01'),
                src.note_ref,
                src.report_index)                               AS report_order,
            (ABS(DATE_DIFF('day', elig.t0_day, note_day.note_date)) <= 90)
                                                                AS in_baseline,
            src.molecular_group,
            src.methods
    FROM    pcx__llm_molecular_report       AS src
    LEFT JOIN pcx__llm_note_date        AS note_day
      ON    src.subject_ref = note_day.subject_ref
     AND    src.note_ref    = note_day.note_ref
    JOIN    pcx__eligible                   AS elig
      ON    src.subject_ref = elig.subject_ref
    WHERE   src.molecular_group <> 'NONE_OF_THE_ABOVE'
),

molecular_pick AS (
    SELECT  subject_ref,
            MAX_BY(report_key, report_order)                            AS ever_key,
            MAX_BY(report_key, report_order) FILTER (WHERE in_baseline) AS baseline_key,
            -- NOT_SUBGROUPED and INDETERMINATE are absence of a result, not groups
            COUNT(DISTINCT molecular_group)
                FILTER (WHERE molecular_group IN ('WNT', 'SHH', 'GROUP_3', 'GROUP_4', 'NON_WNT_NON_SHH'))
                                                                        AS molecular_group_distinct_count,
            BOOL_OR(molecular_group = 'GROUP_3')                        AS group_3_ever_bool
    FROM    molecular_note
    GROUP BY subject_ref
),

molecular AS (
    SELECT  pick.subject_ref,
            ever.molecular_group                                        AS molecular_group_ever,
            baseline.molecular_group                                    AS molecular_group_baseline,
            NULLIF(ever.methods, '')                                    AS molecular_group_method,
            pick.molecular_group_distinct_count,
            pick.group_3_ever_bool
    FROM    molecular_pick          AS pick
    JOIN    molecular_note          AS ever
      ON    ever.subject_ref = pick.subject_ref
     AND    ever.report_key  = pick.ever_key
    LEFT JOIN molecular_note        AS baseline
      ON    baseline.subject_ref = pick.subject_ref
     AND    baseline.report_key  = pick.baseline_key
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
