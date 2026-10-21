-- Study tables for the SQL tests (no clinical data), loaded by tests/sqltest.py with one CSV per
-- table from a data directory: warn/ (hand-written fixtures below) or synthetic/input/ (generated
-- by `make-pcx test-synthetic`, see tests/synthetic.py).
--
-- subjects:  p1 mostly clean   p2 died, salvage-free   p3 tier 2 only   p4 no patient row
--            p5 no birthdate   p6 boundary/conflicts   p7 dates before t0   p8 dates after t0
--            p3 also has a single utilization period (fails include_utilization)

CREATE TABLE core__patient (
    subject_ref VARCHAR,
    birthdate DATE,
    gender VARCHAR
);

CREATE TABLE patient (
    id VARCHAR,
    deceasedBoolean BOOLEAN,
    deceasedDateTime TIMESTAMP
);

CREATE TABLE pcx__cohort_casedef (
    subject_ref VARCHAR,
    subtype VARCHAR,
    tier INTEGER,
    code VARCHAR,
    enc_period_start_day DATE,
    enc_period_start_day_min DATE
);

CREATE TABLE pcx__cohort_casedef_dx (
    subject_ref VARCHAR,
    subtype VARCHAR,
    tier INTEGER,
    dx_onset_date DATE,
    dx_recorded_date DATE
);

CREATE TABLE pcx__include_study_period (
    period_start VARCHAR,
    period_end VARCHAR,
    include_history BOOLEAN
);

CREATE TABLE pcx__cohort_study_period (
    subject_ref VARCHAR,
    period_ordinal INTEGER,
    period_start_day DATE,
    period_end_day DATE,
    encounter_ref VARCHAR
);

CREATE TABLE pcx__cohort_study_population (
    subject_ref VARCHAR,
    enc_period_ordinal INTEGER,
    enc_period_start_day DATE,
    enc_period_end_day_filled DATE
);

CREATE TABLE pcx__include_utilization (
    enc_min INTEGER,
    enc_max INTEGER,
    days_min INTEGER,
    days_max INTEGER
);

CREATE TABLE pcx__llm_diagnosis_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    disease_subtype VARCHAR,
    medulloblastoma_histology VARCHAR,
    chang_m_stage VARCHAR,
    diagnosis_date VARCHAR,
    diagnosis_date_precision VARCHAR,
    diagnosis_day DATE,
    diagnosis_day_precision VARCHAR,
    diagnosis_date_gold VARCHAR,
    diagnosis_date_gold_precision VARCHAR,
    diagnosis_gold_day DATE,
    diagnosis_gold_day_precision VARCHAR,
    age_at_diagnosis_months BIGINT
);

CREATE TABLE pcx__cohort_proc_craniotomy (
    subject_ref VARCHAR,
    proc_performed_day DATE,
    procedure_ref VARCHAR,
    tier VARCHAR  -- study-variable uploads are untyped, so STRING like Athena
);

CREATE TABLE pcx__llm_surgery_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    age_at_surgery_months DOUBLE,
    residual_tumor_area_cm2 DOUBLE,
    surgery_type VARCHAR,
    extent_of_resection VARCHAR,
    surgery_date VARCHAR,
    surgery_date_precision VARCHAR,
    surgery_day DATE,
    surgery_day_precision VARCHAR,
    residual_assessment_date VARCHAR,
    residual_assessment_date_precision VARCHAR,
    residual_assessment_day DATE,
    residual_assessment_day_precision VARCHAR
);

CREATE TABLE pcx__cohort_variable_union_rx (
    subject_ref VARCHAR,
    variable VARCHAR,
    rx_authoredon_date DATE
);

-- dispense seeds: p2 cisplatin handed over before its first order (earliest chemo day),
-- p6 methotrexate (not receipt, so methotrexate_order_only still fires), p5 cancelled and
-- never-handed-over cisplatin (ignored), p1 ondansetron (outside the rx valuesets, ignored)
CREATE TABLE core__medicationdispense (
    subject_ref VARCHAR,
    status VARCHAR,
    medication_system VARCHAR,
    medication_code VARCHAR,
    whenhandedover_day DATE
);

CREATE TABLE pcx__valueset_rx_contrast_methotrexate (
    "system" VARCHAR,
    code VARCHAR
);

CREATE TABLE pcx__valueset_rx_chemo_carboplatin (
    "system" VARCHAR,
    code VARCHAR
);

CREATE TABLE pcx__valueset_rx_chemo_cisplatin (
    "system" VARCHAR,
    code VARCHAR
);

CREATE TABLE pcx__valueset_rx_chemo_cyclophosphamide (
    "system" VARCHAR,
    code VARCHAR
);

CREATE TABLE pcx__valueset_rx_chemo_etoposide (
    "system" VARCHAR,
    code VARCHAR
);

CREATE TABLE pcx__valueset_rx_chemo_thiotepa (
    "system" VARCHAR,
    code VARCHAR
);

CREATE TABLE pcx__valueset_rx_chemo_vincristine (
    "system" VARCHAR,
    code VARCHAR
);

CREATE TABLE pcx__llm_systemic_therapy_agent (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    delivery_status VARCHAR,
    agent_name VARCHAR,
    agent_name_verbatim VARCHAR,
    therapy_start_date VARCHAR,
    therapy_start_date_precision VARCHAR,
    therapy_start_day DATE,
    therapy_start_day_precision VARCHAR,
    therapy_stop_date VARCHAR,
    therapy_stop_date_precision VARCHAR,
    therapy_stop_day DATE,
    therapy_stop_day_precision VARCHAR,
    assessed_through_date VARCHAR,
    assessed_through_date_precision VARCHAR,
    assessed_through_day DATE,
    assessed_through_day_precision VARCHAR
);

CREATE TABLE pcx__cohort_proc_radiation (
    subject_ref VARCHAR,
    proc_performed_day DATE,
    tier VARCHAR  -- study-variable uploads are untyped, so STRING like Athena
);

CREATE TABLE pcx__cohort_dx_radiation (
    subject_ref VARCHAR,
    dx_recorded_date DATE,
    tier VARCHAR,  -- study-variable uploads are untyped, so STRING like Athena
    condition_ref VARCHAR
);

CREATE TABLE pcx__llm_radiation_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    delivery_status VARCHAR,
    radiation_field VARCHAR,
    radiation_method VARCHAR,
    radiation_start_date VARCHAR,
    radiation_start_date_precision VARCHAR,
    radiation_start_day DATE,
    radiation_start_day_precision VARCHAR,
    assessed_through_date VARCHAR,
    assessed_through_date_precision VARCHAR,
    assessed_through_day DATE,
    assessed_through_day_precision VARCHAR,
    radiation_end_date VARCHAR,
    radiation_end_date_precision VARCHAR,
    radiation_end_day DATE,
    radiation_end_day_precision VARCHAR
);

CREATE TABLE pcx__llm_survival_timeline_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    vital_status VARCHAR,
    death_date VARCHAR,
    death_date_precision VARCHAR,
    death_day DATE,
    death_day_precision VARCHAR,
    last_known_alive_date VARCHAR,
    last_known_alive_date_precision VARCHAR,
    last_known_alive_day DATE,
    last_known_alive_day_precision VARCHAR
);

CREATE TABLE pcx__llm_event_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    event_type VARCHAR,
    event_date VARCHAR,
    event_date_precision VARCHAR,
    event_day DATE,
    event_day_precision VARCHAR,
    date_of_progression_mri VARCHAR,
    date_of_progression_mri_precision VARCHAR,
    progression_mri_day DATE,
    progression_mri_day_precision VARCHAR,
    confirmation_date VARCHAR,
    confirmation_date_precision VARCHAR,
    confirmation_day DATE,
    confirmation_day_precision VARCHAR
);

CREATE TABLE pcx__llm_systemic_therapy_regimen (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    protocol_name_verbatim VARCHAR,
    regimen_start_date VARCHAR,
    regimen_start_date_precision VARCHAR,
    regimen_start_day DATE,
    regimen_start_day_precision VARCHAR,
    regimen_stop_date VARCHAR,
    regimen_stop_date_precision VARCHAR,
    regimen_stop_day DATE,
    regimen_stop_day_precision VARCHAR
);

CREATE TABLE pcx__llm_survival_timeline_anchor (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    protocol_name VARCHAR,
    anchor_date VARCHAR,
    anchor_date_precision VARCHAR,
    anchor_day DATE,
    anchor_day_precision VARCHAR
);

CREATE TABLE pcx__sample_casedef_author (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    note_author_date DATE
);

-- LLM tables read only by pcx__warn_llm_date_invalid, empty in the fixtures
CREATE TABLE pcx__llm_laboratory_result (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    collection_date VARCHAR,
    collection_date_precision VARCHAR,
    collection_day DATE,
    collection_day_precision VARCHAR
);

CREATE TABLE pcx__llm_laboratory_toxicity (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    event_date VARCHAR,
    event_date_precision VARCHAR,
    event_day DATE,
    event_day_precision VARCHAR
);

CREATE TABLE pcx__llm_metastasis_site (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    site_date VARCHAR,
    site_date_precision VARCHAR,
    site_day DATE,
    site_day_precision VARCHAR
);

CREATE TABLE pcx__llm_metastasis_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    csf_collection_date VARCHAR,
    csf_collection_date_precision VARCHAR,
    csf_collection_day DATE,
    csf_collection_day_precision VARCHAR,
    brain_mri_date VARCHAR,
    brain_mri_date_precision VARCHAR,
    brain_mri_day DATE,
    brain_mri_day_precision VARCHAR,
    spine_mri_date VARCHAR,
    spine_mri_date_precision VARCHAR,
    spine_mri_day DATE,
    spine_mri_day_precision VARCHAR
);

CREATE TABLE pcx__llm_molecular_alteration (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    report_date VARCHAR,
    report_date_precision VARCHAR,
    report_day DATE,
    report_day_precision VARCHAR
);

CREATE TABLE pcx__llm_molecular_report (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    report_date VARCHAR,
    report_date_precision VARCHAR,
    report_day DATE,
    report_day_precision VARCHAR
);

CREATE TABLE pcx__llm_registry_eligibility_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    age_under_36_months_at_definitive_surgery_assessment_date VARCHAR,
    age_under_36_months_at_definitive_surgery_assessment_date_precision VARCHAR,
    age_under_36_months_at_definitive_surgery_assessment_day DATE,
    age_under_36_months_at_definitive_surgery_assessment_day_precision VARCHAR,
    newly_diagnosed_embryonal_tumor_assessment_date VARCHAR,
    newly_diagnosed_embryonal_tumor_assessment_date_precision VARCHAR,
    newly_diagnosed_embryonal_tumor_assessment_day DATE,
    newly_diagnosed_embryonal_tumor_assessment_day_precision VARCHAR,
    high_risk_disease_assessment_date VARCHAR,
    high_risk_disease_assessment_date_precision VARCHAR,
    high_risk_disease_assessment_day DATE,
    high_risk_disease_assessment_day_precision VARCHAR,
    atrt_excluded_assessment_date VARCHAR,
    atrt_excluded_assessment_date_precision VARCHAR,
    atrt_excluded_assessment_day DATE,
    atrt_excluded_assessment_day_precision VARCHAR,
    no_prior_chemotherapy_assessment_date VARCHAR,
    no_prior_chemotherapy_assessment_date_precision VARCHAR,
    no_prior_chemotherapy_assessment_day DATE,
    no_prior_chemotherapy_assessment_day_precision VARCHAR,
    no_prior_radiation_assessment_date VARCHAR,
    no_prior_radiation_assessment_date_precision VARCHAR,
    no_prior_radiation_assessment_day DATE,
    no_prior_radiation_assessment_day_precision VARCHAR,
    adequate_renal_function_assessment_date VARCHAR,
    adequate_renal_function_assessment_date_precision VARCHAR,
    adequate_renal_function_assessment_day DATE,
    adequate_renal_function_assessment_day_precision VARCHAR,
    adequate_hepatic_function_assessment_date VARCHAR,
    adequate_hepatic_function_assessment_date_precision VARCHAR,
    adequate_hepatic_function_assessment_day DATE,
    adequate_hepatic_function_assessment_day_precision VARCHAR,
    adequate_cardiac_function_assessment_date VARCHAR,
    adequate_cardiac_function_assessment_date_precision VARCHAR,
    adequate_cardiac_function_assessment_day DATE,
    adequate_cardiac_function_assessment_day_precision VARCHAR,
    adequate_pulmonary_function_assessment_date VARCHAR,
    adequate_pulmonary_function_assessment_date_precision VARCHAR,
    adequate_pulmonary_function_assessment_day DATE,
    adequate_pulmonary_function_assessment_day_precision VARCHAR,
    adequate_marrow_function_assessment_date VARCHAR,
    adequate_marrow_function_assessment_date_precision VARCHAR,
    adequate_marrow_function_assessment_day DATE,
    adequate_marrow_function_assessment_day_precision VARCHAR
);

CREATE TABLE pcx__llm_response_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    assessment_date VARCHAR,
    assessment_date_precision VARCHAR,
    assessment_day DATE,
    assessment_day_precision VARCHAR
);

CREATE TABLE pcx__llm_survival_timeline_follow_up (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    assessment_date VARCHAR,
    assessment_date_precision VARCHAR,
    assessment_day DATE,
    assessment_day_precision VARCHAR
);

CREATE TABLE pcx__llm_systemic_therapy_administration (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    administration_date VARCHAR,
    administration_date_precision VARCHAR,
    administration_day DATE,
    administration_day_precision VARCHAR
);

CREATE TABLE pcx__llm_systemic_therapy_cycle (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    cycle_start_date VARCHAR,
    cycle_start_date_precision VARCHAR,
    cycle_start_day DATE,
    cycle_start_day_precision VARCHAR,
    cycle_stop_date VARCHAR,
    cycle_stop_date_precision VARCHAR,
    cycle_stop_day DATE,
    cycle_stop_day_precision VARCHAR
);

CREATE TABLE pcx__llm_systemic_therapy_stem_cell_infusion (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    infusion_date VARCHAR,
    infusion_date_precision VARCHAR,
    infusion_day DATE,
    infusion_day_precision VARCHAR
);

CREATE TABLE pcx__llm_transition_of_care_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    transfer_in_date VARCHAR,
    transfer_in_date_precision VARCHAR,
    transfer_in_day DATE,
    transfer_in_day_precision VARCHAR
);
