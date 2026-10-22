-- ============================================================================
-- Warning: one note has more than one extraction output for an LLM task.
--
-- Grain: one row per task x note. An output is one generated_on, usually a
-- re-run of the same note. The SQL pools every output: client_diagnosis picks
-- one molecular report and one diagnosis value by date, then output, and
-- pcx__exposure_record joins a dose to its agent within one output. A re-run
-- that disagrees with an earlier one therefore does not replace it. The
-- detail lists each output with what it extracted, so the disagreement is
-- visible.
--
--   molecular_note_multiple_outputs          molecular groups, in report order
--   systemic_therapy_note_multiple_outputs   agents, in regimen and agent order
--   diagnosis_note_multiple_outputs          disease subtypes
-- ============================================================================
CREATE TABLE pcx__warn_llm_duplicate_output AS

WITH output AS (
    SELECT  'molecular'                                                         AS task,
            subject_ref,
            note_ref,
            generated_on,
            ARRAY_JOIN(ARRAY_AGG(molecular_group ORDER BY report_index), ',')    AS extracted
    FROM    pcx__llm_molecular_report
    GROUP BY subject_ref, note_ref, generated_on
    UNION ALL
    SELECT  'systemic_therapy',
            subject_ref,
            note_ref,
            generated_on,
            ARRAY_JOIN(ARRAY_AGG(agent_name ORDER BY regimen_index, agent_index), ',')
    FROM    pcx__llm_systemic_therapy_agent
    GROUP BY subject_ref, note_ref, generated_on
    UNION ALL
    SELECT  'diagnosis',
            subject_ref,
            note_ref,
            generated_on,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(disease_subtype)), ',')
    FROM    pcx__llm_diagnosis_wide
    GROUP BY subject_ref, note_ref, generated_on
)

SELECT  CONCAT(task, '_note_multiple_outputs')                                  AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('note=',     note_ref),
            CONCAT('outputs=',  CAST(COUNT(*) AS VARCHAR)),
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(CONCAT(COALESCE(generated_on, 'undated'), '=', extracted))), '|'))
                                                                                AS detail
FROM    output
GROUP BY task, subject_ref, note_ref
HAVING  COUNT(*) > 1
;
