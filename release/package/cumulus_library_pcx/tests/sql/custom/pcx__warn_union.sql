CREATE TABLE pcx__warn_union AS 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_age_disagree' AS test 
 FROM pcx__warn_eligible_age_disagree
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_age_near_36_month_boundary' AS test 
 FROM pcx__warn_eligible_age_near_36_month_boundary
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_dx_date_disagree_fhir_before_llm' AS test 
 FROM pcx__warn_eligible_dx_date_disagree_fhir_before_llm
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_dx_date_disagree_llm_before_fhir' AS test 
 FROM pcx__warn_eligible_dx_date_disagree_llm_before_fhir
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_dx_subtype_conflict' AS test 
 FROM pcx__warn_eligible_dx_subtype_conflict
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_radiation_evidence_conflict' AS test 
 FROM pcx__warn_eligible_radiation_evidence_conflict
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_rx_llm_agent_unrecognized' AS test 
 FROM pcx__warn_eligible_rx_llm_agent_unrecognized
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_subject_missing_patient' AS test 
 FROM pcx__warn_eligible_subject_missing_patient
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_surgery_evidence' AS test 
 FROM pcx__warn_eligible_surgery_evidence
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_surgery_timing' AS test 
 FROM pcx__warn_eligible_surgery_timing
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_t0_after_condition_date' AS test 
 FROM pcx__warn_eligible_t0_after_condition_date
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_t0_anchor_disagree' AS test 
 FROM pcx__warn_eligible_t0_anchor_disagree
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_t0_missing' AS test 
 FROM pcx__warn_eligible_t0_missing
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_eligible_therapy_precedes_t0' AS test 
 FROM pcx__warn_eligible_therapy_precedes_t0
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_llm_date_after_note' AS test 
 FROM pcx__warn_llm_date_after_note
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_llm_date_coarse' AS test 
 FROM pcx__warn_llm_date_coarse
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_outcome_exposure_after_first_event' AS test 
 FROM pcx__warn_outcome_exposure_after_first_event
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_outcome_exposure_order_only' AS test 
 FROM pcx__warn_outcome_exposure_order_only
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_outcome_first_event_timing' AS test 
 FROM pcx__warn_outcome_first_event_timing
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_outcome_survival_days' AS test 
 FROM pcx__warn_outcome_survival_days
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_outcome_vital_status_conflict' AS test 
 FROM pcx__warn_outcome_vital_status_conflict
 UNION ALL 
SELECT COUNT(*) AS cnt, 'pcx__warn_study_period_null_end' AS test 
 FROM pcx__warn_study_period_null_end