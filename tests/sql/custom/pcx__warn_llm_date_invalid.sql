-- ============================================================================
-- Warning: an LLM date that cannot be understood, or whose precision is missing.
--
--   llm_date_invalid             the date text is not understood (below)
--   llm_date_precision_missing   a date with no precision, or a precision with no
--                                date. The model validator that forbids this runs
--                                only in the tests, not at inference.
--
-- The LLM wide tables accept only YYYY-MM-DD, YYYY-MM and YYYY
-- (sql/template/date_macros.sql.jinja), on real calendar days. Any other text,
-- such as a date with no year (10-30), an unreadable year (202?-05-23) or a day
-- that does not exist (2024-02-30), gets a NULL <name>_day, so
-- every downstream stage treats the row as undated. This table lists each one
-- so the note can be reviewed or the task re-run.
-- One row per subject x source column x note x value.
-- ============================================================================
CREATE TABLE pcx__warn_llm_date_invalid AS

WITH candidate AS (
    SELECT  'pcx__llm_diagnosis_wide' AS source_table, 'diagnosis_date' AS date_column,
            subject_ref, note_ref, diagnosis_date AS date_value, diagnosis_date_precision AS precision, diagnosis_day AS date_day
    FROM    pcx__llm_diagnosis_wide
    UNION ALL
    SELECT  'pcx__llm_diagnosis_wide', 'diagnosis_date_gold',
            subject_ref, note_ref, diagnosis_date_gold, diagnosis_date_gold_precision, diagnosis_gold_day
    FROM    pcx__llm_diagnosis_wide
    UNION ALL
    SELECT  'pcx__llm_event_wide', 'event_date',
            subject_ref, note_ref, event_date, event_date_precision, event_day
    FROM    pcx__llm_event_wide
    UNION ALL
    SELECT  'pcx__llm_event_wide', 'date_of_progression_mri',
            subject_ref, note_ref, date_of_progression_mri, date_of_progression_mri_precision, progression_mri_day
    FROM    pcx__llm_event_wide
    UNION ALL
    SELECT  'pcx__llm_event_wide', 'confirmation_date',
            subject_ref, note_ref, confirmation_date, confirmation_date_precision, confirmation_day
    FROM    pcx__llm_event_wide
    UNION ALL
    SELECT  'pcx__llm_laboratory_result', 'collection_date',
            subject_ref, note_ref, collection_date, collection_date_precision, collection_day
    FROM    pcx__llm_laboratory_result
    UNION ALL
    SELECT  'pcx__llm_laboratory_toxicity', 'event_date',
            subject_ref, note_ref, event_date, event_date_precision, event_day
    FROM    pcx__llm_laboratory_toxicity
    UNION ALL
    SELECT  'pcx__llm_metastasis_site', 'site_date',
            subject_ref, note_ref, site_date, site_date_precision, site_day
    FROM    pcx__llm_metastasis_site
    UNION ALL
    SELECT  'pcx__llm_metastasis_wide', 'csf_collection_date',
            subject_ref, note_ref, csf_collection_date, csf_collection_date_precision, csf_collection_day
    FROM    pcx__llm_metastasis_wide
    UNION ALL
    SELECT  'pcx__llm_metastasis_wide', 'brain_mri_date',
            subject_ref, note_ref, brain_mri_date, brain_mri_date_precision, brain_mri_day
    FROM    pcx__llm_metastasis_wide
    UNION ALL
    SELECT  'pcx__llm_metastasis_wide', 'spine_mri_date',
            subject_ref, note_ref, spine_mri_date, spine_mri_date_precision, spine_mri_day
    FROM    pcx__llm_metastasis_wide
    UNION ALL
    SELECT  'pcx__llm_molecular_alteration', 'report_date',
            subject_ref, note_ref, report_date, report_date_precision, report_day
    FROM    pcx__llm_molecular_alteration
    UNION ALL
    SELECT  'pcx__llm_molecular_report', 'report_date',
            subject_ref, note_ref, report_date, report_date_precision, report_day
    FROM    pcx__llm_molecular_report
    UNION ALL
    SELECT  'pcx__llm_radiation_wide', 'assessed_through_date',
            subject_ref, note_ref, assessed_through_date, assessed_through_date_precision, assessed_through_day
    FROM    pcx__llm_radiation_wide
    UNION ALL
    SELECT  'pcx__llm_radiation_wide', 'radiation_start_date',
            subject_ref, note_ref, radiation_start_date, radiation_start_date_precision, radiation_start_day
    FROM    pcx__llm_radiation_wide
    UNION ALL
    SELECT  'pcx__llm_radiation_wide', 'radiation_end_date',
            subject_ref, note_ref, radiation_end_date, radiation_end_date_precision, radiation_end_day
    FROM    pcx__llm_radiation_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'age_under_36_months_at_definitive_surgery_assessment_date',
            subject_ref, note_ref, age_under_36_months_at_definitive_surgery_assessment_date, age_under_36_months_at_definitive_surgery_assessment_date_precision, age_under_36_months_at_definitive_surgery_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'newly_diagnosed_embryonal_tumor_assessment_date',
            subject_ref, note_ref, newly_diagnosed_embryonal_tumor_assessment_date, newly_diagnosed_embryonal_tumor_assessment_date_precision, newly_diagnosed_embryonal_tumor_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'high_risk_disease_assessment_date',
            subject_ref, note_ref, high_risk_disease_assessment_date, high_risk_disease_assessment_date_precision, high_risk_disease_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'atrt_excluded_assessment_date',
            subject_ref, note_ref, atrt_excluded_assessment_date, atrt_excluded_assessment_date_precision, atrt_excluded_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'no_prior_chemotherapy_assessment_date',
            subject_ref, note_ref, no_prior_chemotherapy_assessment_date, no_prior_chemotherapy_assessment_date_precision, no_prior_chemotherapy_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'no_prior_radiation_assessment_date',
            subject_ref, note_ref, no_prior_radiation_assessment_date, no_prior_radiation_assessment_date_precision, no_prior_radiation_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'adequate_renal_function_assessment_date',
            subject_ref, note_ref, adequate_renal_function_assessment_date, adequate_renal_function_assessment_date_precision, adequate_renal_function_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'adequate_hepatic_function_assessment_date',
            subject_ref, note_ref, adequate_hepatic_function_assessment_date, adequate_hepatic_function_assessment_date_precision, adequate_hepatic_function_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'adequate_cardiac_function_assessment_date',
            subject_ref, note_ref, adequate_cardiac_function_assessment_date, adequate_cardiac_function_assessment_date_precision, adequate_cardiac_function_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'adequate_pulmonary_function_assessment_date',
            subject_ref, note_ref, adequate_pulmonary_function_assessment_date, adequate_pulmonary_function_assessment_date_precision, adequate_pulmonary_function_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_registry_eligibility_wide', 'adequate_marrow_function_assessment_date',
            subject_ref, note_ref, adequate_marrow_function_assessment_date, adequate_marrow_function_assessment_date_precision, adequate_marrow_function_assessment_day
    FROM    pcx__llm_registry_eligibility_wide
    UNION ALL
    SELECT  'pcx__llm_response_wide', 'assessment_date',
            subject_ref, note_ref, assessment_date, assessment_date_precision, assessment_day
    FROM    pcx__llm_response_wide
    UNION ALL
    SELECT  'pcx__llm_surgery_wide', 'residual_assessment_date',
            subject_ref, note_ref, residual_assessment_date, residual_assessment_date_precision, residual_assessment_day
    FROM    pcx__llm_surgery_wide
    UNION ALL
    SELECT  'pcx__llm_surgery_wide', 'surgery_date',
            subject_ref, note_ref, surgery_date, surgery_date_precision, surgery_day
    FROM    pcx__llm_surgery_wide
    UNION ALL
    SELECT  'pcx__llm_survival_timeline_anchor', 'anchor_date',
            subject_ref, note_ref, anchor_date, anchor_date_precision, anchor_day
    FROM    pcx__llm_survival_timeline_anchor
    UNION ALL
    SELECT  'pcx__llm_survival_timeline_follow_up', 'assessment_date',
            subject_ref, note_ref, assessment_date, assessment_date_precision, assessment_day
    FROM    pcx__llm_survival_timeline_follow_up
    UNION ALL
    SELECT  'pcx__llm_survival_timeline_wide', 'death_date',
            subject_ref, note_ref, death_date, death_date_precision, death_day
    FROM    pcx__llm_survival_timeline_wide
    UNION ALL
    SELECT  'pcx__llm_survival_timeline_wide', 'last_known_alive_date',
            subject_ref, note_ref, last_known_alive_date, last_known_alive_date_precision, last_known_alive_day
    FROM    pcx__llm_survival_timeline_wide
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_administration', 'administration_date',
            subject_ref, note_ref, administration_date, administration_date_precision, administration_day
    FROM    pcx__llm_systemic_therapy_administration
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_agent', 'therapy_start_date',
            subject_ref, note_ref, therapy_start_date, therapy_start_date_precision, therapy_start_day
    FROM    pcx__llm_systemic_therapy_agent
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_agent', 'therapy_stop_date',
            subject_ref, note_ref, therapy_stop_date, therapy_stop_date_precision, therapy_stop_day
    FROM    pcx__llm_systemic_therapy_agent
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_agent', 'assessed_through_date',
            subject_ref, note_ref, assessed_through_date, assessed_through_date_precision, assessed_through_day
    FROM    pcx__llm_systemic_therapy_agent
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_cycle', 'cycle_start_date',
            subject_ref, note_ref, cycle_start_date, cycle_start_date_precision, cycle_start_day
    FROM    pcx__llm_systemic_therapy_cycle
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_cycle', 'cycle_stop_date',
            subject_ref, note_ref, cycle_stop_date, cycle_stop_date_precision, cycle_stop_day
    FROM    pcx__llm_systemic_therapy_cycle
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_regimen', 'regimen_start_date',
            subject_ref, note_ref, regimen_start_date, regimen_start_date_precision, regimen_start_day
    FROM    pcx__llm_systemic_therapy_regimen
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_regimen', 'regimen_stop_date',
            subject_ref, note_ref, regimen_stop_date, regimen_stop_date_precision, regimen_stop_day
    FROM    pcx__llm_systemic_therapy_regimen
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_stem_cell_infusion', 'infusion_date',
            subject_ref, note_ref, infusion_date, infusion_date_precision, infusion_day
    FROM    pcx__llm_systemic_therapy_stem_cell_infusion
    UNION ALL
    SELECT  'pcx__llm_transition_of_care_wide', 'transfer_in_date',
            subject_ref, note_ref, transfer_in_date, transfer_in_date_precision, transfer_in_day
    FROM    pcx__llm_transition_of_care_wide
)

SELECT  DISTINCT
        CASE
            WHEN date_value IS NOT NULL AND date_day IS NULL                    THEN 'llm_date_invalid'
            ELSE                                                                     'llm_date_precision_missing'
        END                                                                     AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',     source_table),
            CONCAT('column=',    date_column),
            CONCAT('date=',      date_value),
            CONCAT('precision=', precision),
            CONCAT('note=',      note_ref))                                     AS detail
FROM    candidate
WHERE   (date_value IS NOT NULL AND date_day IS NULL)
OR      ((date_value IS NULL) <> (precision IS NULL))
;
