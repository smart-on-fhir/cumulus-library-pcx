-----------------------------------------------------------
-- One row per note with its document type, topic relevance
-- and casedef subject attributes.
-- Task views below select from this table.
-- Document types per task follow DOCUMENT_TASKS in
-- llm/models/document_type.py
--
-- pcx__cohort_casedef has one row per subject x encounter x
-- casedef code, so it is collapsed to its subject attributes
-- first. Joining it on subject_ref alone multiplied every
-- note by every encounter of that subject before DISTINCT.
-----------------------------------------------------------
CREATE  TABLE   pcx__llm_document_task AS
WITH
casedef_subject AS (
    SELECT  DISTINCT
            subject_ref,
            subtype,
            enc_period_start_day_min,
            age_at_casedef_min
    FROM    pcx__cohort_casedef
)
SELECT  DISTINCT
        T.document_type,
        R.*,
        casedef_subject.subtype,
        casedef_subject.enc_period_start_day_min,
        casedef_subject.age_at_casedef_min
FROM    pcx__llm_document_type_wide     AS T
JOIN    pcx__llm_document_topic_wide    AS R
ON      T.note_ref = R.note_ref
AND     T.subject_ref = R.subject_ref
JOIN    casedef_subject
ON      R.subject_ref = casedef_subject.subject_ref
;

-----------------------------------------------------------
-- Diagnosis
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["diagnosis"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_diagnosis AS
SELECT  task.diagnosis_relevance,
        task.diagnosis_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.diagnosis_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'OPERATIVE_NOTE',
            'PATHOLOGY_REPORT',
            'TUMOR_BOARD_NOTE',
            'TRANSFER_DOCUMENT',
            'NEUROSURGERY_NOTE')
;

-----------------------------------------------------------
-- Surgery
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["surgery"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_surgery AS
SELECT  task.surgery_relevance,
        task.surgery_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.surgery_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'OPERATIVE_NOTE',
            'TRANSFER_DOCUMENT',
            'DISCHARGE_SUMMARY',
            'NEUROSURGERY_NOTE')
;

-----------------------------------------------------------
-- Radiation
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["radiation"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_radiation AS
SELECT  task.radiation_relevance,
        task.radiation_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.radiation_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'RADIATION_ONCOLOGY_NOTE',
            'TRANSFER_DOCUMENT',
            'ONCOLOGY_NOTE')
;

-----------------------------------------------------------
-- Systemic Therapy
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["systemic_therapy"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_systemic_therapy AS
SELECT  task.systemic_therapy_relevance,
        task.systemic_therapy_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.systemic_therapy_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'TREATMENT_ADMINISTRATION_RECORD',
            'RESEARCH_PROTOCOL_DOCUMENT',
            'TRANSFER_DOCUMENT',
            'DISCHARGE_SUMMARY',
            'ONCOLOGY_NOTE')
;

-----------------------------------------------------------
-- Metastasis
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["metastasis"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_metastasis AS
SELECT  task.metastasis_relevance,
        task.metastasis_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.metastasis_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'PATHOLOGY_REPORT',
            'IMAGING_REPORT',
            'TUMOR_BOARD_NOTE')
;

-----------------------------------------------------------
-- Molecular
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["molecular"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_molecular AS
SELECT  task.molecular_relevance,
        task.molecular_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.molecular_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'PATHOLOGY_REPORT',
            'GENETICS_DOCUMENT',
            'TUMOR_BOARD_NOTE')
;

-----------------------------------------------------------
-- Response
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["response"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_response AS
SELECT  task.response_relevance,
        task.response_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.response_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'IMAGING_REPORT',
            'RADIATION_ONCOLOGY_NOTE',
            'TUMOR_BOARD_NOTE',
            'ONCOLOGY_NOTE')
;

-----------------------------------------------------------
-- Event
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["event"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_event AS
SELECT  task.event_relevance,
        task.event_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.event_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'IMAGING_REPORT',
            'RADIATION_ONCOLOGY_NOTE',
            'DISCHARGE_SUMMARY',
            'END_OF_LIFE_DOCUMENT',
            'NEUROSURGERY_NOTE',
            'ONCOLOGY_NOTE',
            'NONE_OF_THE_ABOVE')
;

-----------------------------------------------------------
-- Laboratory
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["laboratory"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_laboratory AS
SELECT  task.laboratory_relevance,
        task.laboratory_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.laboratory_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'DISCHARGE_SUMMARY',
            'ONCOLOGY_NOTE')
;

-----------------------------------------------------------
-- Registry Eligibility
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["registry_eligibility"]
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_registry_eligibility AS
SELECT  task.registry_eligibility_relevance,
        task.registry_eligibility_confidence,
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.registry_eligibility_relevance IN ('EXPLICIT', 'IMPLICIT')
OR      task.document_type IN (
            'TUMOR_BOARD_NOTE',
            'RESEARCH_PROTOCOL_DOCUMENT',
            'ONCOLOGY_NOTE')
;

-----------------------------------------------------------
-- Transition of care
-- document type only: document_topic has no
-- transition_of_care topic
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_transition_of_care AS
SELECT  DISTINCT
        task.document_type,
        task.note_ref,
        task.subject_ref
FROM    pcx__llm_document_task AS task
WHERE   task.document_type IN (
            'TRANSFER_DOCUMENT',
            'DISCHARGE_SUMMARY',
            'NEUROSURGERY_NOTE',
            'ONCOLOGY_NOTE')
;

-----------------------------------------------------------
-- Survival timeline
-- relevance: explicit/implicit
-- or document type in DOCUMENT_TASKS["survival_timeline"]
--
-- Only notes from each subject's last clinical visit, the
-- latest encounter day among the qualifying notes.
-- Vital status and last known alive are documented at the
-- last visit, there are no visits after death.
-----------------------------------------------------------
CREATE OR REPLACE VIEW pcx__llm_document_task_survival_timeline AS
WITH
encounter_day AS (
    SELECT  DISTINCT
            encounter_ref,
            enc_period_start_day
    FROM    pcx__cohort_study_population
),
survival_note AS (
    SELECT  task.survival_timeline_relevance,
            task.survival_timeline_confidence,
            task.document_type,
            task.note_ref,
            task.encounter_ref,
            task.subject_ref,
            encounter_day.enc_period_start_day
    FROM    pcx__llm_document_task AS task
    JOIN    encounter_day
    ON      task.encounter_ref = encounter_day.encounter_ref
    WHERE   task.survival_timeline_relevance IN ('EXPLICIT', 'IMPLICIT')
    OR      task.document_type IN (
                'RESEARCH_PROTOCOL_DOCUMENT',
                'DISCHARGE_SUMMARY',
                'END_OF_LIFE_DOCUMENT',
                'ONCOLOGY_NOTE',
                'NONE_OF_THE_ABOVE')
),
last_visit AS (
    SELECT  subject_ref,
            MAX(enc_period_start_day) AS enc_period_start_day
    FROM    survival_note
    GROUP BY subject_ref
)
SELECT  survival_note.*
FROM    survival_note
JOIN    last_visit
ON      survival_note.subject_ref = last_visit.subject_ref
AND     survival_note.enc_period_start_day = last_visit.enc_period_start_day
;
