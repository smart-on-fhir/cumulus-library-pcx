--  =====================================================================
--  Note date spine: one row per note the LLM tasks read
--
--  Every note in pcx__sample_task, the casedef notes and the Elasticsearch
--  search notes alike (pcx__sample_casedef_author covers casedef notes only).
--  note_date is, in order:
--    DocumentReference   author day, else DocumentReference.date
--    DiagnosticReport    effectiveDateTime day, else effectivePeriod start
--  the same rule pcx__sample_casedef uses to sort notes. A note with
--  conflicting dates has a NULL note_date and note_date_conflict_bool TRUE.
--  A note with no date at all still has a row, with a NULL note_date.
--  Read by client_diagnosis, client_timeline and pcx__warn_llm_date_after_note.
--  =====================================================================
CREATE  TABLE   pcx__llm_note_date AS
WITH
task_note AS (
    SELECT  DISTINCT subject_ref, note_ref
    FROM    pcx__sample_task
),
note_day AS (
    SELECT  task_note.subject_ref,
            task_note.note_ref,
            COALESCE(doc.author_day, DATE(doc."date"),
                     diag.effectivedatetime_day, diag.effectiveperiod_start_day)   AS note_day
    FROM    task_note
    LEFT JOIN core__documentreference   AS doc
    ON      doc.documentreference_ref = task_note.note_ref
    LEFT JOIN core__diagnosticreport    AS diag
    ON      diag.diagnosticreport_ref = task_note.note_ref
)
SELECT  subject_ref,
        note_ref,
        CASE WHEN COUNT(DISTINCT note_day) = 1 THEN MIN(note_day) END   AS note_date,
        COUNT(DISTINCT note_day) > 1                                    AS note_date_conflict_bool
FROM    note_day
GROUP BY subject_ref, note_ref
;
