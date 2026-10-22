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
        cycle.phase                                                  AS phase,
        cycle.protocol_name                                          AS protocol_name,
        cycle.protocol_name_verbatim                                 AS protocol_name_verbatim,
        cycle.completion_status                                      AS completion_status,
        cycle.interruption_reason                                    AS interruption_reason,
        cycle.cycle_num                                              AS cycle_num,
        cycle.cycle_name_verbatim                                    AS cycle_name_verbatim,
        cycle.cycle_start_date                                       AS cycle_start_date,
        cycle.cycle_start_date_precision                             AS cycle_start_date_precision,
        CASE
            WHEN cycle.cycle_start_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(cycle.cycle_start_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(cycle.cycle_start_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(cycle.cycle_start_date) = 4 OR cycle.cycle_start_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(cycle.cycle_start_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(cycle.cycle_start_date) = 7 OR cycle.cycle_start_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(cycle.cycle_start_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(cycle.cycle_start_date AS DATE)
        END AS cycle_start_day,
        CASE
            WHEN cycle.cycle_start_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(cycle.cycle_start_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(cycle.cycle_start_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(cycle.cycle_start_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(cycle.cycle_start_date) = 4 OR cycle.cycle_start_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(cycle.cycle_start_date) = 7 OR cycle.cycle_start_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS cycle_start_day_precision,
        cycle.cycle_stop_date                                        AS cycle_stop_date,
        cycle.cycle_stop_date_precision                              AS cycle_stop_date_precision,
        CASE
            WHEN cycle.cycle_stop_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(cycle.cycle_stop_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(cycle.cycle_stop_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(cycle.cycle_stop_date) = 4 OR cycle.cycle_stop_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(cycle.cycle_stop_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(cycle.cycle_stop_date) = 7 OR cycle.cycle_stop_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(cycle.cycle_stop_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(cycle.cycle_stop_date AS DATE)
        END AS cycle_stop_day,
        CASE
            WHEN cycle.cycle_stop_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(cycle.cycle_stop_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(cycle.cycle_stop_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(cycle.cycle_stop_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(cycle.cycle_stop_date) = 4 OR cycle.cycle_stop_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(cycle.cycle_stop_date) = 7 OR cycle.cycle_stop_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS cycle_stop_day_precision
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.cycles) WITH ORDINALITY AS cycle_t (cycle, cycle_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
