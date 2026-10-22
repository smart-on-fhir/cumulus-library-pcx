CREATE TABLE pcx__llm_event_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_event_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        event_index,
        event.event_type                                             AS event_type,
        event.source_of_event_diagnosis                              AS source_of_event_diagnosis,
        event.event_date                                             AS event_date,
        event.event_date_precision                                   AS event_date_precision,
        CASE
            WHEN event.event_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(event.event_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(event.event_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(event.event_date) = 4 OR event.event_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(event.event_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(event.event_date) = 7 OR event.event_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(event.event_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(event.event_date AS DATE)
        END AS event_day,
        CASE
            WHEN event.event_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(event.event_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(event.event_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(event.event_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(event.event_date) = 4 OR event.event_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(event.event_date) = 7 OR event.event_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS event_day_precision,
        event.date_of_progression_mri                                AS date_of_progression_mri,
        event.date_of_progression_mri_precision                      AS date_of_progression_mri_precision,
        CASE
            WHEN event.date_of_progression_mri IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(event.date_of_progression_mri, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(event.date_of_progression_mri, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(event.date_of_progression_mri) = 4 OR event.date_of_progression_mri_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(event.date_of_progression_mri, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(event.date_of_progression_mri) = 7 OR event.date_of_progression_mri_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(event.date_of_progression_mri, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(event.date_of_progression_mri AS DATE)
        END AS progression_mri_day,
        CASE
            WHEN event.date_of_progression_mri IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(event.date_of_progression_mri, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(event.date_of_progression_mri, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(event.date_of_progression_mri, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(event.date_of_progression_mri) = 4 OR event.date_of_progression_mri_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(event.date_of_progression_mri) = 7 OR event.date_of_progression_mri_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS progression_mri_day_precision,
        event.confirmation_date                                      AS confirmation_date,
        event.confirmation_date_precision                            AS confirmation_date_precision,
        CASE
            WHEN event.confirmation_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(event.confirmation_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(event.confirmation_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(event.confirmation_date) = 4 OR event.confirmation_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(event.confirmation_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(event.confirmation_date) = 7 OR event.confirmation_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(event.confirmation_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(event.confirmation_date AS DATE)
        END AS confirmation_day,
        CASE
            WHEN event.confirmation_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(event.confirmation_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(event.confirmation_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(event.confirmation_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(event.confirmation_date) = 4 OR event.confirmation_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(event.confirmation_date) = 7 OR event.confirmation_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS confirmation_day_precision
FROM
        pcx__nlp_event_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.events) WITH ORDINALITY AS event_t (event, event_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
