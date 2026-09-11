-- ============================================================================
-- Grain: one row per event_id
--
-- One long table of dated evidence for every client subject: coded FHIR
-- evidence from the study-variable unions and the case definition, every
-- LLM chart-review task that has a wide table, and the derived anchors and
-- outcomes. Same 20-column contract as the IBD client timeline so downstream
-- tooling is shared. therapy_line_number is always NULL in PCX, rx_class
-- carries METHOTREXATE / CHEMOTHERAPY for medication rows.
--
-- Dates: coded rows use the resource date, else the encounter start. LLM rows
-- use the extracted date when the model gave one (date_type = extracted, with
-- its precision), else the note author date from the shared spine
-- (date_type = documented). Extracted dates are hard CAST to DATE so a
-- malformed value fails the build instead of vanishing.
-- Document routing tasks (document_type, document_topic) are not events.
-- ============================================================================
CREATE TABLE pcx__client_timeline AS
WITH
events AS (

-- ========================================================================
-- SECTION: CODED FHIR EVIDENCE
-- ========================================================================

-- ----------------------------------------------------------------------
-- pcx__cohort_variable_union_lab
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref_link                                       AS encounter_ref,
        src.variable                                                 AS variable,
        CASE WHEN src.lab_effectivedate_day IS NOT NULL THEN src.lab_effectivedate_day ELSE DATE(sp.enc_period_start_day) END AS event_date,
        src.lab_effectivedate_day                                    AS evidence_date,
        CASE WHEN src.lab_effectivedate_day IS NOT NULL THEN 'effective' ELSE 'encounter' END AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.lab_valuestring                                          AS value_text,
        CAST(src.lab_valuequantity_value AS DOUBLE)                  AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        src.lab_valuequantity_unit                                   AS unit,
        src.lab_interpretation_code                                  AS interpretation,
        src.lab_status                                               AS status,
        src.code                                                     AS code,
        src.system                                                   AS code_system,
        'FHIR'                                                       AS source_type,
        'evidence'                                                   AS assertion_level,
        src.observation_ref                                          AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__cohort_variable_union_lab       AS src
LEFT JOIN pcx__cohort_study_population AS sp
  ON    src.encounter_ref_link = sp.encounter_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__cohort_variable_union_dx
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref_link                                       AS encounter_ref,
        src.variable                                                 AS variable,
        CASE WHEN src.dx_onset_date IS NOT NULL THEN src.dx_onset_date WHEN src.dx_recorded_date IS NOT NULL THEN src.dx_recorded_date ELSE DATE(sp.enc_period_start_day) END AS event_date,
        src.dx_recorded_date                                         AS evidence_date,
        CASE WHEN src.dx_onset_date IS NOT NULL THEN 'onset' WHEN src.dx_recorded_date IS NOT NULL THEN 'recorded' ELSE 'encounter' END AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.display                                                  AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(src.tier AS VARCHAR)                                    AS interpretation,
        src.dx_clinical_status                                       AS status,
        src.code                                                     AS code,
        src.system                                                   AS code_system,
        'FHIR'                                                       AS source_type,
        'evidence'                                                   AS assertion_level,
        src.condition_ref                                            AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__cohort_variable_union_dx        AS src
LEFT JOIN pcx__cohort_study_population AS sp
  ON    src.encounter_ref_link = sp.encounter_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__cohort_variable_union_rx
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref_link                                       AS encounter_ref,
        src.variable                                                 AS variable,
        CASE WHEN src.rx_authoredon_date IS NOT NULL THEN src.rx_authoredon_date ELSE DATE(sp.enc_period_start_day) END AS event_date,
        src.rx_authoredon_date                                       AS evidence_date,
        CASE WHEN src.rx_authoredon_date IS NOT NULL THEN 'authored' ELSE 'encounter' END AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.rx_medication_display                                    AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        src.rx_status                                                AS status,
        src.code                                                     AS code,
        src.system                                                   AS code_system,
        'FHIR'                                                       AS source_type,
        'evidence'                                                   AS assertion_level,
        src.medicationrequest_ref                                    AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CASE WHEN src.variable = 'rx_contrast_methotrexate' THEN 'METHOTREXATE' WHEN src.variable LIKE 'rx_chemo_%' THEN 'CHEMOTHERAPY' END AS rx_class
FROM    pcx__cohort_variable_union_rx        AS src
LEFT JOIN pcx__cohort_study_population AS sp
  ON    src.encounter_ref_link = sp.encounter_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__cohort_variable_union_proc
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref_link                                       AS encounter_ref,
        src.variable                                                 AS variable,
        CASE WHEN src.proc_performed_day IS NOT NULL THEN src.proc_performed_day ELSE DATE(sp.enc_period_start_day) END AS event_date,
        src.proc_performed_day                                       AS evidence_date,
        CASE WHEN src.proc_performed_day IS NOT NULL THEN 'performed' ELSE 'encounter' END AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.proc_display                                             AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(src.tier AS VARCHAR)                                    AS interpretation,
        src.proc_status                                              AS status,
        src.code                                                     AS code,
        src.system                                                   AS code_system,
        'FHIR'                                                       AS source_type,
        'evidence'                                                   AS assertion_level,
        src.procedure_ref                                            AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__cohort_variable_union_proc      AS src
LEFT JOIN pcx__cohort_study_population AS sp
  ON    src.encounter_ref_link = sp.encounter_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__cohort_casedef
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref_link                                       AS encounter_ref,
        'casedef_subtype'                                            AS variable,
        DATE(src.enc_period_start_day)                               AS event_date,
        DATE(src.enc_period_start_day)                               AS evidence_date,
        'encounter'                                                  AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.subtype                                                  AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(src.tier AS VARCHAR)                                    AS interpretation,
        src.casedef_period                                           AS status,
        src.code                                                     AS code,
        src.system                                                   AS code_system,
        'FHIR'                                                       AS source_type,
        'evidence'                                                   AS assertion_level,
        src.resource_ref                                             AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__cohort_casedef                  AS src
WHERE   src.subtype IS NOT NULL

UNION ALL

-- ========================================================================
-- SECTION: LLM CHART REVIEW (note dates from pcx__sample_casedef_author)
-- ========================================================================

-- ----------------------------------------------------------------------
-- pcx__llm_diagnosis_wide.disease_subtype
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_disease_subtype'                                        AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.disease_subtype                                          AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.historical_diagnosis_term                                AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_diagnosis_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.disease_subtype <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_diagnosis_wide.medulloblastoma_histology
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_medulloblastoma_histology'                              AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.medulloblastoma_histology                                AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_diagnosis_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.medulloblastoma_histology <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_diagnosis_wide.chang_m_stage
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_chang_m_stage'                                          AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.chang_m_stage                                            AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_diagnosis_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.chang_m_stage <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_diagnosis_wide.tumor_location_verbatim
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_tumor_location'                                         AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.tumor_location_verbatim                                  AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_diagnosis_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.tumor_location_verbatim IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_diagnosis_wide.age_at_diagnosis_months
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_age_at_diagnosis_months'                                AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        CAST(NULL AS VARCHAR)                                        AS value_text,
        CAST(src.age_at_diagnosis_months AS DOUBLE)                  AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        'months'                                                     AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_diagnosis_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.age_at_diagnosis_months IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_diagnosis_wide.diagnosis_date
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_diagnosis_date'                                         AS variable,
        CASE WHEN src.diagnosis_date IS NOT NULL THEN CAST(src.diagnosis_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.diagnosis_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.diagnosis_date_precision                                 AS date_precision,
        CAST(NULL AS VARCHAR)                                        AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        TRUE                                                         AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_diagnosis_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.diagnosis_date IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_diagnosis_wide.diagnosis_date_gold
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_diagnosis_date_gold'                                    AS variable,
        CASE WHEN src.diagnosis_date_gold IS NOT NULL THEN CAST(src.diagnosis_date_gold AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.diagnosis_date_gold IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.diagnosis_date_gold_precision                            AS date_precision,
        CAST(NULL AS VARCHAR)                                        AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        TRUE                                                         AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_diagnosis_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.diagnosis_date_gold IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_surgery_wide (surgery)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_surgery'                                                AS variable,
        CASE WHEN src.surgery_date IS NOT NULL THEN CAST(src.surgery_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.surgery_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.surgery_date_precision                                   AS date_precision,
        src.surgery_type                                             AS value_text,
        src.age_at_surgery_months                                    AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        'months'                                                     AS unit,
        src.extent_of_resection                                      AS interpretation,
        src.surgery_role                                             AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_surgery_wide                AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.surgery_type <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_surgery_wide (residual tumor area)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_surgery_residual_area'                                  AS variable,
        CASE WHEN src.residual_assessment_date IS NOT NULL THEN CAST(src.residual_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.residual_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.residual_assessment_date_precision                       AS date_precision,
        src.residual_measurement_verbatim                            AS value_text,
        src.residual_tumor_area_cm2                                  AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        'cm2'                                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        src.surgery_role                                             AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_surgery_wide                AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.residual_tumor_area_cm2 IS NOT NULL OR src.residual_measurement_verbatim IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_radiation_wide (round)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_radiation'                                              AS variable,
        CASE WHEN src.radiation_start_date IS NOT NULL THEN CAST(src.radiation_start_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.radiation_start_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.radiation_start_date_precision                           AS date_precision,
        src.radiation_field                                          AS value_text,
        src.total_dose_to_primary_site                               AS value_number,
        (src.delivery_status = 'ADMINISTERED')                       AS value_boolean,
        CAST(src.dose_units AS VARCHAR)                              AS unit,
        src.radiation_method                                         AS interpretation,
        src.delivery_status                                          AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_radiation_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_radiation_wide (craniospinal dose)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_radiation_craniospinal_dose'                            AS variable,
        CASE WHEN src.radiation_start_date IS NOT NULL THEN CAST(src.radiation_start_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.radiation_start_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.radiation_start_date_precision                           AS date_precision,
        CAST(NULL AS VARCHAR)                                        AS value_text,
        src.craniospinal_dose                                        AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(src.dose_units AS VARCHAR)                              AS unit,
        src.indication                                               AS interpretation,
        src.delivery_status                                          AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_radiation_wide              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.craniospinal_dose IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_event_wide
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_event'                                                  AS variable,
        CASE WHEN src.event_date IS NOT NULL THEN CAST(src.event_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.event_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.event_date_precision                                     AS date_precision,
        src.event_type                                               AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.source_of_event_diagnosis                                AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_event_wide                  AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.event_type <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_patient_wide (death)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_death'                                                  AS variable,
        CASE WHEN src.death_date IS NOT NULL THEN CAST(src.death_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.death_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.death_date_precision                                     AS date_precision,
        src.vital_status                                             AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        TRUE                                                         AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_patient_wide                AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.vital_status = 'DECEASED'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_patient_wide (last known alive)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_last_known_alive'                                       AS variable,
        CASE WHEN src.last_known_alive_date IS NOT NULL THEN CAST(src.last_known_alive_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.last_known_alive_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.last_known_alive_date_precision                          AS date_precision,
        src.vital_status                                             AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        TRUE                                                         AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_patient_wide                AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.last_known_alive_date IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_patient_anchor
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_timeline_anchor'                                        AS variable,
        CASE WHEN src.anchor_date IS NOT NULL THEN CAST(src.anchor_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.anchor_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.anchor_date_precision                                    AS date_precision,
        src.anchor                                                   AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.protocol_name                                            AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_patient_anchor              AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_patient_follow_up
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_event_free_follow_up'                                   AS variable,
        CASE WHEN src.assessment_date IS NOT NULL THEN CAST(src.assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.assessment_date_precision                                AS date_precision,
        CAST(NULL AS VARCHAR)                                        AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        src.event_free                                               AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.assessment_method                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_patient_follow_up           AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_systemic_therapy_agent
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_therapy_agent'                                          AS variable,
        CASE WHEN src.therapy_start_date IS NOT NULL THEN CAST(src.therapy_start_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.therapy_start_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.therapy_start_date_precision                             AS date_precision,
        src.agent_name                                               AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        (src.delivery_status = 'ADMINISTERED')                       AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        src.delivery_status                                          AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CASE WHEN LOWER(src.agent_name) LIKE '%methotrexate%' OR LOWER(src.agent_name) LIKE '%mtx%' THEN 'METHOTREXATE' WHEN src.agent_name IS NOT NULL THEN 'CHEMOTHERAPY' END AS rx_class
FROM    pcx__llm_systemic_therapy_agent      AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_systemic_therapy_regimen
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_therapy_regimen'                                        AS variable,
        CASE WHEN src.regimen_start_date IS NOT NULL THEN CAST(src.regimen_start_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.regimen_start_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.regimen_start_date_precision                             AS date_precision,
        src.protocol_name_verbatim                                   AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.phase                                                    AS interpretation,
        src.documented_trial_arm                                     AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_systemic_therapy_regimen    AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_systemic_therapy_administration
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_therapy_administration'                                 AS variable,
        CASE WHEN src.administration_date IS NOT NULL THEN CAST(src.administration_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.administration_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.administration_date_precision                            AS date_precision,
        src.route                                                    AS value_text,
        src.dose_amount                                              AS value_number,
        src.high_dose_methotrexate_explicit_bool                     AS value_boolean,
        src.dose_unit                                                AS unit,
        src.phase                                                    AS interpretation,
        src.delivery_status                                          AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_systemic_therapy_administration AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_systemic_therapy_cycle
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_therapy_cycle'                                          AS variable,
        CASE WHEN src.cycle_start_date IS NOT NULL THEN CAST(src.cycle_start_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.cycle_start_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.cycle_start_date_precision                               AS date_precision,
        src.cycle_name                                               AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.phase                                                    AS interpretation,
        src.completion_status                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_systemic_therapy_cycle      AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_systemic_therapy_stem_cell_infusion
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_stem_cell_infusion'                                     AS variable,
        CASE WHEN src.infusion_date IS NOT NULL THEN CAST(src.infusion_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.infusion_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.infusion_date_precision                                  AS date_precision,
        src.cell_source                                              AS value_text,
        src.cd34_cells_per_kg                                        AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        'cells/kg'                                                   AS unit,
        src.phase                                                    AS interpretation,
        src.delivery_status                                          AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_systemic_therapy_stem_cell_infusion AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_response_wide
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_response'                                               AS variable,
        CASE WHEN src.assessment_date IS NOT NULL THEN CAST(src.assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.assessment_date_precision                                AS date_precision,
        src.response                                                 AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        src.radiologically_evaluable                                 AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.timepoint                                                AS interpretation,
        src.assessment_method                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_response_wide               AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.response <> 'NOT_DOCUMENTED' OR src.radiologically_evaluable IS NOT NULL OR src.cytologically_evaluable IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_metastasis_wide.csf_cytology
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_csf_cytology'                                           AS variable,
        CASE WHEN src.csf_collection_date IS NOT NULL THEN CAST(src.csf_collection_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.csf_collection_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.csf_collection_date_precision                            AS date_precision,
        src.csf_cytology                                             AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.csf_collection_site                                      AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_metastasis_wide             AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.csf_cytology <> 'UNAVAILABLE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_metastasis_wide.spine_mri_findings
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_spine_mri'                                              AS variable,
        CASE WHEN src.spine_mri_date IS NOT NULL THEN CAST(src.spine_mri_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.spine_mri_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.spine_mri_date_precision                                 AS date_precision,
        src.spine_mri_findings                                       AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_metastasis_wide             AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.spine_mri_findings <> 'UNAVAILABLE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_metastasis_wide.brain_mri_findings
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_brain_mri'                                              AS variable,
        CASE WHEN src.brain_mri_date IS NOT NULL THEN CAST(src.brain_mri_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.brain_mri_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.brain_mri_date_precision                                 AS date_precision,
        src.brain_mri_findings                                       AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_metastasis_wide             AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.brain_mri_findings <> 'UNAVAILABLE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_metastasis_wide.extraneural_metastasis
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_extraneural_metastasis'                                 AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.extraneural_metastasis                                   AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_metastasis_wide             AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.extraneural_metastasis <> 'UNAVAILABLE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_metastasis_site
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_metastatic_site'                                        AS variable,
        CASE WHEN src.site_date IS NOT NULL THEN CAST(src.site_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.site_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.site_date_precision                                      AS date_precision,
        src.site                                                     AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_metastasis_site             AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.site <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_medulloblastoma_wide.molecular_group
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_molecular_group'                                        AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.molecular_group                                          AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.molecular_group_classification_method                    AS interpretation,
        src.molecular_group_source_report                            AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_medulloblastoma_wide        AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.molecular_group <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_medulloblastoma_wide.methotrexate_status
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_methotrexate_any_dose'                                  AS variable,
        CASE WHEN src.methotrexate_first_received_date IS NOT NULL THEN src.methotrexate_first_received_date ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.methotrexate_first_received_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.methotrexate_status                                      AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        (src.methotrexate_status = 'RECEIVED')                       AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        'METHOTREXATE'                                               AS rx_class
FROM    pcx__llm_medulloblastoma_wide        AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.methotrexate_status <> 'NOT_DOCUMENTED'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_medulloblastoma_wide.radiation_status
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_radiation_any_dose'                                     AS variable,
        CASE WHEN src.radiation_first_received_date IS NOT NULL THEN src.radiation_first_received_date ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.radiation_first_received_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.radiation_status                                         AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        (src.radiation_status = 'RECEIVED')                          AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_medulloblastoma_wide        AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.radiation_status <> 'NOT_DOCUMENTED'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.age_under_36_months_at_definitive_surgery
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_age_under_36_months_at_definitive_surgery'        AS variable,
        CASE WHEN src.age_under_36_months_at_definitive_surgery_assessment_date IS NOT NULL THEN CAST(src.age_under_36_months_at_definitive_surgery_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.age_under_36_months_at_definitive_surgery_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.age_under_36_months_at_definitive_surgery_assessment_date_precision AS date_precision,
        src.age_under_36_months_at_definitive_surgery_status         AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.age_under_36_months_at_definitive_surgery_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.age_under_36_months_at_definitive_surgery_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.newly_diagnosed_embryonal_tumor
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_newly_diagnosed_embryonal_tumor'                  AS variable,
        CASE WHEN src.newly_diagnosed_embryonal_tumor_assessment_date IS NOT NULL THEN CAST(src.newly_diagnosed_embryonal_tumor_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.newly_diagnosed_embryonal_tumor_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.newly_diagnosed_embryonal_tumor_assessment_date_precision AS date_precision,
        src.newly_diagnosed_embryonal_tumor_status                   AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.newly_diagnosed_embryonal_tumor_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.newly_diagnosed_embryonal_tumor_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.high_risk_disease
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_high_risk_disease'                                AS variable,
        CASE WHEN src.high_risk_disease_assessment_date IS NOT NULL THEN CAST(src.high_risk_disease_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.high_risk_disease_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.high_risk_disease_assessment_date_precision              AS date_precision,
        src.high_risk_disease_status                                 AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.high_risk_disease_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.high_risk_disease_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.atrt_excluded
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_atrt_excluded'                                    AS variable,
        CASE WHEN src.atrt_excluded_assessment_date IS NOT NULL THEN CAST(src.atrt_excluded_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.atrt_excluded_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.atrt_excluded_assessment_date_precision                  AS date_precision,
        src.atrt_excluded_status                                     AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.atrt_excluded_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.atrt_excluded_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.no_prior_chemotherapy
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_no_prior_chemotherapy'                            AS variable,
        CASE WHEN src.no_prior_chemotherapy_assessment_date IS NOT NULL THEN CAST(src.no_prior_chemotherapy_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.no_prior_chemotherapy_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.no_prior_chemotherapy_assessment_date_precision          AS date_precision,
        src.no_prior_chemotherapy_status                             AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.no_prior_chemotherapy_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.no_prior_chemotherapy_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.no_prior_radiation
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_no_prior_radiation'                               AS variable,
        CASE WHEN src.no_prior_radiation_assessment_date IS NOT NULL THEN CAST(src.no_prior_radiation_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.no_prior_radiation_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.no_prior_radiation_assessment_date_precision             AS date_precision,
        src.no_prior_radiation_status                                AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.no_prior_radiation_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.no_prior_radiation_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.adequate_renal_function
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_adequate_renal_function'                          AS variable,
        CASE WHEN src.adequate_renal_function_assessment_date IS NOT NULL THEN CAST(src.adequate_renal_function_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.adequate_renal_function_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.adequate_renal_function_assessment_date_precision        AS date_precision,
        src.adequate_renal_function_status                           AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.adequate_renal_function_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.adequate_renal_function_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.adequate_hepatic_function
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_adequate_hepatic_function'                        AS variable,
        CASE WHEN src.adequate_hepatic_function_assessment_date IS NOT NULL THEN CAST(src.adequate_hepatic_function_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.adequate_hepatic_function_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.adequate_hepatic_function_assessment_date_precision      AS date_precision,
        src.adequate_hepatic_function_status                         AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.adequate_hepatic_function_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.adequate_hepatic_function_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.adequate_cardiac_function
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_adequate_cardiac_function'                        AS variable,
        CASE WHEN src.adequate_cardiac_function_assessment_date IS NOT NULL THEN CAST(src.adequate_cardiac_function_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.adequate_cardiac_function_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.adequate_cardiac_function_assessment_date_precision      AS date_precision,
        src.adequate_cardiac_function_status                         AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.adequate_cardiac_function_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.adequate_cardiac_function_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.adequate_pulmonary_function
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_adequate_pulmonary_function'                      AS variable,
        CASE WHEN src.adequate_pulmonary_function_assessment_date IS NOT NULL THEN CAST(src.adequate_pulmonary_function_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.adequate_pulmonary_function_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.adequate_pulmonary_function_assessment_date_precision    AS date_precision,
        src.adequate_pulmonary_function_status                       AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.adequate_pulmonary_function_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.adequate_pulmonary_function_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_registry_eligibility_wide.adequate_marrow_function
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_trial_adequate_marrow_function'                         AS variable,
        CASE WHEN src.adequate_marrow_function_assessment_date IS NOT NULL THEN CAST(src.adequate_marrow_function_assessment_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.adequate_marrow_function_assessment_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.adequate_marrow_function_assessment_date_precision       AS date_precision,
        src.adequate_marrow_function_status                          AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CASE src.adequate_marrow_function_status WHEN 'MET' THEN TRUE WHEN 'NOT_MET' THEN FALSE END AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_registry_eligibility_wide   AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.adequate_marrow_function_status <> 'UNKNOWN'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_transition_of_care_wide.transfer_in
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_transfer_in'                                            AS variable,
        CASE WHEN src.transfer_in_date IS NOT NULL THEN CAST(src.transfer_in_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.transfer_in_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.transfer_in_date_precision                               AS date_precision,
        src.transfer_in_timing                                       AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.transfer_in_reason                                       AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_transition_of_care_wide     AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.transfer_in_timing <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_transition_of_care_wide.diagnosis_setting
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_diagnosis_setting'                                      AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.diagnosis_setting                                        AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        src.imaging_detected_externally                              AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_transition_of_care_wide     AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.diagnosis_setting <> 'NONE_OF_THE_ABOVE' OR src.imaging_detected_externally IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_transition_of_care_wide.surgery_setting
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_surgery_setting'                                        AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.surgery_setting                                          AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_transition_of_care_wide     AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.surgery_setting <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_transition_of_care_wide.prior_therapy_at_entry
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_prior_therapy_at_entry'                                 AS variable,
        note_day.note_author_date                                    AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        'documented'                                                 AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.prior_therapy_exposure                                   AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        ARRAY_JOIN(src.prior_therapy_modalities, '|')                AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_transition_of_care_wide     AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref
WHERE   src.prior_therapy_exposure <> 'NONE_OF_THE_ABOVE'

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_laboratory_result
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_laboratory_result'                                      AS variable,
        CASE WHEN src.collection_date IS NOT NULL THEN CAST(src.collection_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.collection_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.collection_date_precision                                AS date_precision,
        CAST(src.test AS VARCHAR)                                    AS value_text,
        src.value                                                    AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        src.units                                                    AS unit,
        src.context                                                  AS interpretation,
        src.reference_range                                          AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_laboratory_result           AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_laboratory_toxicity
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_toxicity'                                               AS variable,
        CASE WHEN src.event_date IS NOT NULL THEN CAST(src.event_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.event_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.event_date_precision                                     AS date_precision,
        src.toxicity                                                 AS value_text,
        CAST(src.grade AS DOUBLE)                                    AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.attribution                                              AS interpretation,
        src.phase                                                    AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_laboratory_toxicity         AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__llm_predisposition_wide
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        src.encounter_ref                                            AS encounter_ref,
        'llm_predisposition'                                         AS variable,
        CASE WHEN src.report_date IS NOT NULL THEN CAST(src.report_date AS DATE) ELSE note_day.note_author_date END AS event_date,
        note_day.note_author_date                                    AS evidence_date,
        CASE WHEN src.report_date IS NOT NULL THEN 'extracted' ELSE 'documented' END AS date_type,
        src.report_date_precision                                    AS date_precision,
        src.gene_or_syndrome                                         AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        src.status                                                   AS interpretation,
        src.variant_verbatim                                         AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'LLM'                                                        AS source_type,
        'evidence'                                                   AS assertion_level,
        src.note_ref                                                 AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__llm_predisposition_wide         AS src
LEFT JOIN pcx__sample_casedef_author AS note_day
  ON    src.subject_ref = note_day.subject_ref
 AND    src.note_ref    = note_day.note_ref

UNION ALL

-- ========================================================================
-- SECTION: DERIVED (eligible and outcome stages)
-- ========================================================================

-- ----------------------------------------------------------------------
-- pcx__eligible (time zero)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        CAST(NULL AS VARCHAR)                                        AS encounter_ref,
        't0'                                                         AS variable,
        src.t0_day                                                   AS event_date,
        CAST(NULL AS DATE)                                           AS evidence_date,
        'derived'                                                    AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.t0_source                                                AS value_text,
        CAST(src.age_months_at_t0 AS DOUBLE)                         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        'months'                                                     AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'DERIVED'                                                    AS source_type,
        'derived'                                                    AS assertion_level,
        CAST(NULL AS VARCHAR)                                        AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__eligible                        AS src
WHERE   src.t0_day IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__eligible (definitive surgery)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        CAST(NULL AS VARCHAR)                                        AS encounter_ref,
        'definitive_surgery'                                         AS variable,
        src.definitive_surgery_day                                   AS event_date,
        CAST(NULL AS DATE)                                           AS evidence_date,
        'derived'                                                    AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.definitive_surgery_source                                AS value_text,
        CAST(src.age_months_at_definitive_surgery AS DOUBLE)         AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        'months'                                                     AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'DERIVED'                                                    AS source_type,
        'derived'                                                    AS assertion_level,
        CAST(NULL AS VARCHAR)                                        AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__eligible                        AS src
WHERE   src.definitive_surgery_day IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__outcome_first_event
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        CAST(NULL AS VARCHAR)                                        AS encounter_ref,
        'first_event'                                                AS variable,
        src.first_event_day                                          AS event_date,
        CAST(NULL AS DATE)                                           AS evidence_date,
        'derived'                                                    AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        src.first_event_type                                         AS value_text,
        CAST(src.days_t0_to_first_event AS DOUBLE)                   AS value_number,
        CAST(NULL AS BOOLEAN)                                        AS value_boolean,
        'days'                                                       AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'DERIVED'                                                    AS source_type,
        'derived'                                                    AS assertion_level,
        CAST(NULL AS VARCHAR)                                        AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__outcome_first_event             AS src
WHERE   src.first_event_day IS NOT NULL

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__outcome_vital_status (death)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        CAST(NULL AS VARCHAR)                                        AS encounter_ref,
        'death'                                                      AS variable,
        src.death_day                                                AS event_date,
        CAST(NULL AS DATE)                                           AS evidence_date,
        'derived'                                                    AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        CAST(NULL AS VARCHAR)                                        AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        src.deceased_bool                                            AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'DERIVED'                                                    AS source_type,
        'derived'                                                    AS assertion_level,
        CAST(NULL AS VARCHAR)                                        AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__outcome_vital_status            AS src
WHERE   src.deceased_bool

UNION ALL

-- ----------------------------------------------------------------------
-- pcx__outcome_vital_status (last known alive)
-- ----------------------------------------------------------------------
SELECT  DISTINCT
        src.subject_ref                                              AS subject_ref,
        CAST(NULL AS VARCHAR)                                        AS encounter_ref,
        'last_known_alive'                                           AS variable,
        src.last_known_alive_day                                     AS event_date,
        CAST(NULL AS DATE)                                           AS evidence_date,
        'derived'                                                    AS date_type,
        CAST(NULL AS VARCHAR)                                        AS date_precision,
        CAST(NULL AS VARCHAR)                                        AS value_text,
        CAST(NULL AS DOUBLE)                                         AS value_number,
        TRUE                                                         AS value_boolean,
        CAST(NULL AS VARCHAR)                                        AS unit,
        CAST(NULL AS VARCHAR)                                        AS interpretation,
        CAST(NULL AS VARCHAR)                                        AS status,
        CAST(NULL AS VARCHAR)                                        AS code,
        CAST(NULL AS VARCHAR)                                        AS code_system,
        'DERIVED'                                                    AS source_type,
        'derived'                                                    AS assertion_level,
        CAST(NULL AS VARCHAR)                                        AS source_ref,
        CAST(NULL AS INTEGER)                                        AS therapy_line_number,
        CAST(NULL AS VARCHAR)                                        AS rx_class
FROM    pcx__outcome_vital_status            AS src
WHERE   src.last_known_alive_day IS NOT NULL
),

-- Date plausibility, applied once for every branch above.
-- A date outside [1980-01-01, today] is not a real observation - it is a
-- placeholder, a typo, or a mis-parsed partial date - so it is reported as
-- unknown rather than passed to downstream date arithmetic. Applying it here,
-- before the fingerprint, keeps event_id consistent with the row it names, and
-- lets pcx__client_timeline_latest and pcx__client_dictionary_coverage inherit
-- the rule instead of restating it. Rows are never dropped, only their dates
-- are cleared.
guarded AS (
    SELECT  events.subject_ref,
            events.encounter_ref,
            events.variable,
            CASE
                WHEN events.event_date
                     BETWEEN DATE '1980-01-01' AND CURRENT_DATE
                THEN events.event_date
                ELSE NULL
            END                                                 AS event_date,
            CASE
                WHEN events.evidence_date
                     BETWEEN DATE '1980-01-01' AND CURRENT_DATE
                THEN events.evidence_date
                ELSE NULL
            END                                                 AS evidence_date,
            events.date_type,
            events.date_precision,
            events.value_text,
            events.value_number,
            events.value_boolean,
            events.unit,
            events.interpretation,
            events.status,
            events.code,
            events.code_system,
            events.source_type,
            events.assertion_level,
            events.source_ref,
            events.therapy_line_number,
            events.rx_class
    FROM    events
)

-- Reproducible row fingerprint. CAST(... AS VARBINARY) is the one spelling
-- both Trino and DuckDB accept. event_id only has to be unique and stable
-- WITHIN one warehouse. The CHR(31) separator and the '~' COALESCE sentinels
-- make the digest defined for NULLs and unambiguous across field boundaries.
SELECT  TO_HEX(SHA1(CAST(CONCAT_WS(CHR(31),
            COALESCE(guarded.subject_ref, '~'),
            COALESCE(guarded.encounter_ref, '~'),
            COALESCE(guarded.variable, '~'),
            COALESCE(CAST(guarded.event_date AS VARCHAR), '~'),
            COALESCE(CAST(guarded.evidence_date AS VARCHAR), '~'),
            COALESCE(guarded.date_type, '~'),
            COALESCE(guarded.date_precision, '~'),
            COALESCE(guarded.value_text, '~'),
            COALESCE(CAST(guarded.value_number AS VARCHAR), '~'),
            COALESCE(CAST(guarded.value_boolean AS VARCHAR), '~'),
            COALESCE(guarded.unit, '~'),
            COALESCE(guarded.interpretation, '~'),
            COALESCE(guarded.status, '~'),
            COALESCE(guarded.code, '~'),
            COALESCE(guarded.code_system, '~'),
            COALESCE(guarded.source_type, '~'),
            COALESCE(guarded.assertion_level, '~'),
            COALESCE(guarded.source_ref, '~'),
            COALESCE(CAST(guarded.therapy_line_number AS VARCHAR), '~'),
            COALESCE(guarded.rx_class, '~')) AS VARBINARY)))
        AS event_id,
        guarded.*
FROM    guarded
JOIN    pcx__client_subject AS subject
  ON    guarded.subject_ref = subject.subject_ref
;
