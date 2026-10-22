CREATE TABLE pcx__llm_systemic_therapy_administration AS
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
        administration_index,
        administration.delivery_status                               AS delivery_status,
        administration.phase                                         AS phase,
        administration.cycle_num                                     AS cycle_num,
        administration.cycle_day                                     AS cycle_day,
        administration.cycle_name_verbatim                           AS cycle_name_verbatim,
        administration.administration_date                           AS administration_date,
        administration.administration_date_precision                 AS administration_date_precision,
        CASE
            WHEN administration.administration_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(administration.administration_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(administration.administration_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(administration.administration_date) = 4 OR administration.administration_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(administration.administration_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(administration.administration_date) = 7 OR administration.administration_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(administration.administration_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(administration.administration_date AS DATE)
        END AS administration_day,
        CASE
            WHEN administration.administration_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(administration.administration_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(administration.administration_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(administration.administration_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(administration.administration_date) = 4 OR administration.administration_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(administration.administration_date) = 7 OR administration.administration_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS administration_day_precision,
        administration.dose_amount                                   AS dose_amount,
        administration.dose_unit                                     AS dose_unit,
        administration.route                                         AS route,
        administration.high_dose_methotrexate_explicit_bool          AS high_dose_methotrexate_explicit_bool
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.regimens) WITH ORDINALITY AS regimen_t (regimen, regimen_index)
CROSS JOIN UNNEST(regimen.agents) WITH ORDINALITY AS agent_t (agent, agent_index)
CROSS JOIN UNNEST(agent.administrations) WITH ORDINALITY AS administration_t (administration, administration_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
