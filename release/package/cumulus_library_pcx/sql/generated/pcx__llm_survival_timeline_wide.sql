CREATE TABLE pcx__llm_survival_timeline_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_survival_timeline_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        nlp.result.vital_status.vital_status                         AS vital_status,
        nlp.result.vital_status.death_date                           AS death_date,
        nlp.result.vital_status.death_date_precision                 AS death_date_precision,
        CASE
            WHEN nlp.result.vital_status.death_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.vital_status.death_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.vital_status.death_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.vital_status.death_date) = 4 OR nlp.result.vital_status.death_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.vital_status.death_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.vital_status.death_date) = 7 OR nlp.result.vital_status.death_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.vital_status.death_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.vital_status.death_date AS DATE)
        END AS death_day,
        CASE
            WHEN nlp.result.vital_status.death_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.vital_status.death_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.vital_status.death_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.vital_status.death_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.vital_status.death_date) = 4 OR nlp.result.vital_status.death_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.vital_status.death_date) = 7 OR nlp.result.vital_status.death_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS death_day_precision,
        nlp.result.vital_status.last_known_alive_date                AS last_known_alive_date,
        nlp.result.vital_status.last_known_alive_date_precision      AS last_known_alive_date_precision,
        CASE
            WHEN nlp.result.vital_status.last_known_alive_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.vital_status.last_known_alive_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.vital_status.last_known_alive_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.vital_status.last_known_alive_date) = 4 OR nlp.result.vital_status.last_known_alive_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.vital_status.last_known_alive_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.vital_status.last_known_alive_date) = 7 OR nlp.result.vital_status.last_known_alive_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.vital_status.last_known_alive_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.vital_status.last_known_alive_date AS DATE)
        END AS last_known_alive_day,
        CASE
            WHEN nlp.result.vital_status.last_known_alive_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.vital_status.last_known_alive_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.vital_status.last_known_alive_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.vital_status.last_known_alive_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.vital_status.last_known_alive_date) = 4 OR nlp.result.vital_status.last_known_alive_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.vital_status.last_known_alive_date) = 7 OR nlp.result.vital_status.last_known_alive_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS last_known_alive_day_precision
FROM
        pcx__nlp_survival_timeline_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
