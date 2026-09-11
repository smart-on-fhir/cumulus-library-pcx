CREATE TABLE pcx__llm_systemic_therapy_agent AS
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
        agent_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        agent.delivery_status                                        AS delivery_status,
        agent.agent_name                                             AS agent_name,
        agent.therapy_start_date                                     AS therapy_start_date,
        agent.therapy_start_date_precision                           AS therapy_start_date_precision,
        agent.therapy_stop_date                                      AS therapy_stop_date,
        agent.therapy_stop_date_precision                            AS therapy_stop_date_precision
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.regimens) WITH ORDINALITY AS regimen_t (regimen, regimen_index)
CROSS JOIN UNNEST(regimen.agents) WITH ORDINALITY AS agent_t (agent, agent_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
