CREATE TABLE pcx__llm_systemic_therapy_regimen AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_systemic_therapy_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        regimen_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        regimen.phase                                                AS phase,
        regimen.documented_trial_arm                                 AS documented_trial_arm,
        regimen.protocol_name_verbatim                               AS protocol_name_verbatim,
        regimen.regimen_start_date                                   AS regimen_start_date,
        regimen.regimen_start_date_precision                         AS regimen_start_date_precision,
        regimen.regimen_stop_date                                    AS regimen_stop_date,
        regimen.regimen_stop_date_precision                          AS regimen_stop_date_precision
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.regimens) WITH ORDINALITY AS regimen_t (regimen, regimen_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
