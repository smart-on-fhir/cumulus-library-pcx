

CREATE TABLE pcx__sample_casedef_peri_limit_patient_10 AS
WITH note_dates AS (
    SELECT subject_ref, note_ref, MIN(sort_by_date) AS sort_by_date
    FROM pcx__sample_casedef_peri
    GROUP BY subject_ref, note_ref
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY subject_ref ORDER BY sort_by_date NULLS LAST, note_ref) AS note_rank,
           DENSE_RANK() OVER (ORDER BY subject_ref) AS patient_rank
    FROM note_dates
)
SELECT source.*
FROM pcx__sample_casedef_peri AS source
JOIN ranked ON source.subject_ref = ranked.subject_ref AND source.note_ref = ranked.note_ref
WHERE patient_rank <= 10;

