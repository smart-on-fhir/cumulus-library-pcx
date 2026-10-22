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
        agent.delivery_status                                        AS delivery_status,
        agent.agent_name                                             AS agent_name,
        agent.agent_name_verbatim                                    AS agent_name_verbatim,
        agent.therapy_start_date                                     AS therapy_start_date,
        agent.therapy_start_date_precision                           AS therapy_start_date_precision,
        CASE
            WHEN agent.therapy_start_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(agent.therapy_start_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(agent.therapy_start_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(agent.therapy_start_date) = 4 OR agent.therapy_start_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(agent.therapy_start_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(agent.therapy_start_date) = 7 OR agent.therapy_start_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(agent.therapy_start_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(agent.therapy_start_date AS DATE)
        END AS therapy_start_day,
        CASE
            WHEN agent.therapy_start_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(agent.therapy_start_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(agent.therapy_start_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(agent.therapy_start_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(agent.therapy_start_date) = 4 OR agent.therapy_start_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(agent.therapy_start_date) = 7 OR agent.therapy_start_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS therapy_start_day_precision,
        agent.therapy_stop_date                                      AS therapy_stop_date,
        agent.therapy_stop_date_precision                            AS therapy_stop_date_precision,
        CASE
            WHEN agent.therapy_stop_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(agent.therapy_stop_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(agent.therapy_stop_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(agent.therapy_stop_date) = 4 OR agent.therapy_stop_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(agent.therapy_stop_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(agent.therapy_stop_date) = 7 OR agent.therapy_stop_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(agent.therapy_stop_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(agent.therapy_stop_date AS DATE)
        END AS therapy_stop_day,
        CASE
            WHEN agent.therapy_stop_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(agent.therapy_stop_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(agent.therapy_stop_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(agent.therapy_stop_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(agent.therapy_stop_date) = 4 OR agent.therapy_stop_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(agent.therapy_stop_date) = 7 OR agent.therapy_stop_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS therapy_stop_day_precision,
        agent.assessed_through_date                                  AS assessed_through_date,
        agent.assessed_through_date_precision                        AS assessed_through_date_precision,
        CASE
            WHEN agent.assessed_through_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(agent.assessed_through_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(agent.assessed_through_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(agent.assessed_through_date) = 4 OR agent.assessed_through_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(agent.assessed_through_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(agent.assessed_through_date) = 7 OR agent.assessed_through_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(agent.assessed_through_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(agent.assessed_through_date AS DATE)
        END AS assessed_through_day,
        CASE
            WHEN agent.assessed_through_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(agent.assessed_through_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(agent.assessed_through_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(agent.assessed_through_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(agent.assessed_through_date) = 4 OR agent.assessed_through_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(agent.assessed_through_date) = 7 OR agent.assessed_through_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS assessed_through_day_precision
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.regimens) WITH ORDINALITY AS regimen_t (regimen, regimen_index)
CROSS JOIN UNNEST(regimen.agents) WITH ORDINALITY AS agent_t (agent, agent_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
