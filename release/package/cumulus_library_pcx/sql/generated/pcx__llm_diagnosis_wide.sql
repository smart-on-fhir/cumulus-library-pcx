CREATE TABLE pcx__llm_diagnosis_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_diagnosis_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        nlp.result.disease_subtype.disease_subtype                          AS disease_subtype,
        nlp.result.medulloblastoma_histology.histology                      AS medulloblastoma_histology,
        nlp.result.disease_subtype.historical_diagnosis_term                AS historical_diagnosis_term,
        nlp.result.chang_m_stage.chang_m_stage                              AS chang_m_stage,
        nlp.result.age_at_diagnosis.age_at_diagnosis_months                 AS age_at_diagnosis_months,
        nlp.result.diagnosis_date.diagnosis_date                            AS diagnosis_date,
        nlp.result.diagnosis_date.diagnosis_date_precision                  AS diagnosis_date_precision,
        CASE
            WHEN nlp.result.diagnosis_date.diagnosis_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.diagnosis_date.diagnosis_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.diagnosis_date.diagnosis_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.diagnosis_date.diagnosis_date) = 4 OR nlp.result.diagnosis_date.diagnosis_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.diagnosis_date.diagnosis_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.diagnosis_date.diagnosis_date) = 7 OR nlp.result.diagnosis_date.diagnosis_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.diagnosis_date.diagnosis_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.diagnosis_date.diagnosis_date AS DATE)
        END AS diagnosis_day,
        CASE
            WHEN nlp.result.diagnosis_date.diagnosis_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.diagnosis_date.diagnosis_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.diagnosis_date.diagnosis_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.diagnosis_date.diagnosis_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.diagnosis_date.diagnosis_date) = 4 OR nlp.result.diagnosis_date.diagnosis_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.diagnosis_date.diagnosis_date) = 7 OR nlp.result.diagnosis_date.diagnosis_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS diagnosis_day_precision,
        nlp.result.diagnosis_date_gold.diagnosis_date_gold                  AS diagnosis_date_gold,
        nlp.result.diagnosis_date_gold.diagnosis_date_gold_precision        AS diagnosis_date_gold_precision,
        CASE
            WHEN nlp.result.diagnosis_date_gold.diagnosis_date_gold IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.diagnosis_date_gold.diagnosis_date_gold, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.diagnosis_date_gold.diagnosis_date_gold) = 4 OR nlp.result.diagnosis_date_gold.diagnosis_date_gold_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.diagnosis_date_gold.diagnosis_date_gold, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.diagnosis_date_gold.diagnosis_date_gold) = 7 OR nlp.result.diagnosis_date_gold.diagnosis_date_gold_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.diagnosis_date_gold.diagnosis_date_gold, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.diagnosis_date_gold.diagnosis_date_gold AS DATE)
        END AS diagnosis_gold_day,
        CASE
            WHEN nlp.result.diagnosis_date_gold.diagnosis_date_gold IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.diagnosis_date_gold.diagnosis_date_gold, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.diagnosis_date_gold.diagnosis_date_gold, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.diagnosis_date_gold.diagnosis_date_gold) = 4 OR nlp.result.diagnosis_date_gold.diagnosis_date_gold_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.diagnosis_date_gold.diagnosis_date_gold) = 7 OR nlp.result.diagnosis_date_gold.diagnosis_date_gold_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS diagnosis_gold_day_precision
FROM
        pcx__nlp_diagnosis_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     task_version = 2
