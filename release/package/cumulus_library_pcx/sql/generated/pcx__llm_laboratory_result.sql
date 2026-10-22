CREATE TABLE pcx__llm_laboratory_result AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_laboratory_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        result_index,
        lab_result.test                                                  AS test,
        lab_result.value_numeric                                         AS value_numeric,
        lab_result.value_type                                            AS value_type,
        lab_result.value_unit                                            AS value_unit,
        lab_result.trend                                                 AS trend,
        lab_result.interp_instrument                                     AS interp_instrument,
        lab_result.interp_clinician                                      AS interp_clinician,
        lab_result.interp_llm                                            AS interp_llm,
        lab_result.reference_range                                       AS reference_range,
        lab_result.collection_date                                       AS collection_date,
        lab_result.collection_date_precision                             AS collection_date_precision,
        CASE
            WHEN lab_result.collection_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(lab_result.collection_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(lab_result.collection_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(lab_result.collection_date) = 4 OR lab_result.collection_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(lab_result.collection_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(lab_result.collection_date) = 7 OR lab_result.collection_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(lab_result.collection_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(lab_result.collection_date AS DATE)
        END AS collection_day,
        CASE
            WHEN lab_result.collection_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(lab_result.collection_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(lab_result.collection_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(lab_result.collection_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(lab_result.collection_date) = 4 OR lab_result.collection_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(lab_result.collection_date) = 7 OR lab_result.collection_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS collection_day_precision
FROM
        pcx__nlp_laboratory_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.results) WITH ORDINALITY AS result_t (lab_result, result_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 3
