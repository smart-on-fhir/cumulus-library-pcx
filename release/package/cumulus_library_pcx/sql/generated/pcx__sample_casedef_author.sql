-- One date per subject/note, conflicting non-null dates remain unknown.
CREATE TABLE pcx__sample_casedef_author AS
SELECT subject_ref, note_ref,
       CASE WHEN COUNT(DISTINCT note_author_date) = 1 THEN MIN(note_author_date) END AS note_author_date,
       COUNT(DISTINCT note_author_date) > 1 AS note_date_conflict_bool
FROM pcx__sample_casedef
GROUP BY subject_ref, note_ref;
