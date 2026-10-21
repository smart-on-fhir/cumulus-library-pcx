-- ============================================================================
-- Warning: an LLM date later than the note that states it.
--
-- A diagnosis, death, last-alive, event, administered therapy or radiation
-- start date cannot fall after the date of the note it was read from.
-- Such a date is a misread (year typo, a scheduled date taken as delivered)
-- and the eligible / outcome stages consume it as fact. Surgery dates are
-- included because eligible_surgery does not check delivery status, so a
-- scheduled operation can become the definitive surgery day.
-- Note dates come from pcx__llm_note_date, the note date spine for every note
-- the LLM tasks read (casedef and Elasticsearch notes).
-- ============================================================================
CREATE TABLE pcx__warn_llm_date_after_note AS

WITH candidate AS (
    SELECT  'pcx__llm_diagnosis_wide' AS source_table, 'diagnosis_date' AS date_column,
            subject_ref, note_ref, diagnosis_day AS llm_day
    FROM    pcx__llm_diagnosis_wide
    WHERE   diagnosis_day IS NOT NULL
    UNION ALL
    SELECT  'pcx__llm_diagnosis_wide', 'diagnosis_date_gold',
            subject_ref, note_ref, diagnosis_gold_day
    FROM    pcx__llm_diagnosis_wide
    WHERE   diagnosis_gold_day IS NOT NULL
    UNION ALL
    SELECT  'pcx__llm_surgery_wide', 'surgery_date',
            subject_ref, note_ref, surgery_day
    FROM    pcx__llm_surgery_wide
    WHERE   surgery_day IS NOT NULL
    UNION ALL
    SELECT  'pcx__llm_event_wide', 'event_date',
            subject_ref, note_ref, event_day
    FROM    pcx__llm_event_wide
    WHERE   event_day IS NOT NULL
    AND     event_type IN ('PROGRESSION', 'RECURRENCE', 'SECOND_MALIGNANCY', 'DECEASED')
    UNION ALL
    SELECT  'pcx__llm_survival_timeline_wide', 'death_date',
            subject_ref, note_ref, death_day
    FROM    pcx__llm_survival_timeline_wide
    WHERE   death_day IS NOT NULL
    UNION ALL
    SELECT  'pcx__llm_survival_timeline_wide', 'last_known_alive_date',
            subject_ref, note_ref, last_known_alive_day
    FROM    pcx__llm_survival_timeline_wide
    WHERE   last_known_alive_day IS NOT NULL
    UNION ALL
    SELECT  'pcx__llm_systemic_therapy_agent', 'therapy_start_date',
            subject_ref, note_ref, therapy_start_day
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   therapy_start_day IS NOT NULL
    AND     delivery_status = 'ADMINISTERED'
    UNION ALL
    SELECT  'pcx__llm_radiation_wide', 'radiation_start_date',
            subject_ref, note_ref, radiation_start_day
    FROM    pcx__llm_radiation_wide
    WHERE   radiation_start_day IS NOT NULL
    AND     delivery_status = 'ADMINISTERED'
)

SELECT  DISTINCT
        'llm_date_after_note'                                                   AS warn_check,
        CAST(candidate.subject_ref AS VARCHAR)                                  AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',    candidate.source_table),
            CONCAT('column=',   candidate.date_column),
            CONCAT('llm=',      CAST(candidate.llm_day AS VARCHAR)),
            CONCAT('note_date=',CAST(author.note_date AS VARCHAR)),
            CONCAT('days=',     CAST(DATE_DIFF('day', author.note_date, candidate.llm_day) AS VARCHAR)),
            CONCAT('note=',     candidate.note_ref))                            AS detail
FROM    candidate
JOIN    pcx__llm_note_date  AS author
ON      author.note_ref     = candidate.note_ref
AND     author.subject_ref  = candidate.subject_ref
WHERE   author.note_date IS NOT NULL
AND     candidate.llm_day > author.note_date
;
