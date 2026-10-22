-- ============================================================================
-- Warning: one note has more than one molecular extraction output.
--
-- Grain: one row per note. An output is one (generated_on, system_fingerprint)
-- pair, usually a re-run of the same note. pcx__client_diagnosis pools every
-- output (a real group beats an uncertain one, then the latest output), so a
-- re-run that disagrees with an earlier one does not replace it. The detail
-- lists each output with its groups so the disagreement is visible.
--
--   molecular_note_multiple_outputs  more than one output for the note
-- ============================================================================
CREATE TABLE pcx__warn_llm_molecular_duplicate_output AS

WITH output AS (
    SELECT  subject_ref,
            note_ref,
            CONCAT(COALESCE(generated_on, 'undated'), '/', COALESCE(system_fingerprint, 'none'), '=',
                   ARRAY_JOIN(ARRAY_AGG(molecular_group ORDER BY report_index), ','))  AS output_groups
    FROM    pcx__llm_molecular_report
    GROUP BY subject_ref, note_ref, generated_on, system_fingerprint
)

SELECT  'molecular_note_multiple_outputs'               AS warn_check,
        CAST(subject_ref AS VARCHAR)                    AS subject_ref,
        CONCAT_WS('|',
            CONCAT('note=',     note_ref),
            CONCAT('outputs=',  CAST(COUNT(*) AS VARCHAR)),
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(output_groups)), '|'))  AS detail
FROM    output
GROUP BY subject_ref, note_ref
HAVING  COUNT(*) > 1
;
