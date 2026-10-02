-- One row per subject; nullable follow-up remains missing in the exported data.
CREATE TABLE {{ prefix }}__analysis AS
SELECT eligible.subject_ref, eligible.index_date, outcome.next_encounter_date,
       date_diff('day', eligible.index_date, outcome.next_encounter_date) AS days_to_next_encounter
FROM {{ prefix }}__eligible AS eligible
LEFT JOIN {{ prefix }}__outcome AS outcome
ON eligible.subject_ref = outcome.subject_ref;
