CREATE TABLE pcx__llm_systemic_therapy_cycle AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_systemic_therapy_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        cycle_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        cycle.phase                                                  AS phase,
        cycle.protocol_name_verbatim                                 AS protocol_name_verbatim,
        cycle.completion_status                                      AS completion_status,
        cycle.interruption_reason                                    AS interruption_reason,
        cycle.cycle_name                                             AS cycle_name,
        cycle.cycle_start_date                                       AS cycle_start_date,
        cycle.cycle_start_date_precision                             AS cycle_start_date_precision,
        cycle.cycle_stop_date                                        AS cycle_stop_date,
        cycle.cycle_stop_date_precision                              AS cycle_stop_date_precision
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.cycles) WITH ORDINALITY AS cycle_t (cycle, cycle_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
