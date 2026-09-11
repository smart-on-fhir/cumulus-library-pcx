-- ============================================================================
-- Warning: an LLM date with MONTH or YEAR precision consumed as an exact day.
--
-- Coarse dates are stored as the first day of the period. The eligible and
-- outcome stages CAST them to DATE and compare them with structured days, so
-- a YEAR-precision death date of 2021-01-01 becomes an OS end day, and a
-- MONTH-precision surgery date can move a child across the 36-month line.
-- One row per subject x source column x note.
-- ============================================================================
CREATE TABLE pcx__warn_llm_date_coarse AS

WITH candidate AS (
    SELECT  'pcx__llm_diagnosis_wide' AS source_table, 'diagnosis_date' AS date_column,
            subject_ref, note_ref, diagnosis_date AS date_value, diagnosis_date_precision AS precision
    FROM    pcx__llm_diagnosis_wide
    UNION ALL
    SELECT  'pcx__llm_diagnosis_wide', 'diagnosis_date_gold',
            subject_ref, note_ref, diagnosis_date_gold, diagnosis_date_gold_precision
    FROM    pcx__llm_diagnosis_wide
    UNION ALL
    SELECT  'pcx__llm_surgery_wide', 'surgery_date',
            subject_ref, note_ref, surgery_date, surgery_date_precision
    FROM    pcx__llm_surgery_wide
    UNION ALL
    SELECT  'pcx__llm_event_wide', 'event_date',
            subject_ref, note_ref, event_date, event_date_precision
    FROM    pcx__llm_event_wide
    WHERE   event_type IN ('PROGRESSION', 'RECURRENCE', 'SECOND_MALIGNANCY', 'DECEASED')
    UNION ALL
    SELECT  'pcx__llm_patient_wide', 'death_date',
            subject_ref, note_ref, death_date, death_date_precision
    FROM    pcx__llm_patient_wide
    UNION ALL
    SELECT  'pcx__llm_patient_wide', 'last_known_alive_date',
            subject_ref, note_ref, last_known_alive_date, last_known_alive_date_precision
    FROM    pcx__llm_patient_wide
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_agent', 'therapy_start_date',
            subject_ref, note_ref, therapy_start_date, therapy_start_date_precision
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   delivery_status = 'ADMINISTERED'
    UNION ALL
    SELECT  'pcx__llm_radiation_wide', 'radiation_start_date',
            subject_ref, note_ref, radiation_start_date, radiation_start_date_precision
    FROM    pcx__llm_radiation_wide
    WHERE   delivery_status = 'ADMINISTERED'
)

SELECT  DISTINCT
        CONCAT('llm_date_coarse_', LOWER(precision))                            AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',    source_table),
            CONCAT('column=',   date_column),
            CONCAT('date=',     date_value),
            CONCAT('note=',     note_ref))                                      AS detail
FROM    candidate
WHERE   date_value IS NOT NULL
AND     precision IN ('MONTH', 'YEAR')
;
