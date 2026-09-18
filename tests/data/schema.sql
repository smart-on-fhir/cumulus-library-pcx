-- Synthetic study tables for the SQL tests (no clinical data).
-- One CSV per table in this directory, loaded by tests/sqltest.py.
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
    diagnosis_date_gold VARCHAR,
    diagnosis_date_gold_precision VARCHAR,
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
    surgery_date_precision VARCHAR
);

CREATE TABLE pcx__cohort_variable_union_rx (
    subject_ref VARCHAR,
    variable VARCHAR,
    rx_authoredon_date DATE
);

CREATE TABLE pcx__llm_systemic_therapy_agent (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    delivery_status VARCHAR,
    agent_name VARCHAR,
    therapy_start_date VARCHAR,
    therapy_start_date_precision VARCHAR
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
    radiation_start_date_precision VARCHAR
);

CREATE TABLE pcx__llm_survival_timeline_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    vital_status VARCHAR,
    death_date VARCHAR,
    death_date_precision VARCHAR,
    last_known_alive_date VARCHAR,
    last_known_alive_date_precision VARCHAR
);

CREATE TABLE pcx__llm_event_wide (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    event_type VARCHAR,
    event_date VARCHAR,
    event_date_precision VARCHAR
);

CREATE TABLE pcx__llm_systemic_therapy_regimen (
    subject_ref VARCHAR,
    protocol_name_verbatim VARCHAR
);

CREATE TABLE pcx__llm_survival_timeline_anchor (
    subject_ref VARCHAR,
    protocol_name VARCHAR
);

CREATE TABLE pcx__sample_casedef_author (
    subject_ref VARCHAR,
    note_ref VARCHAR,
    note_author_date DATE
);
