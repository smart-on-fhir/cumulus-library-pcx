CREATE TABLE pcx__llm_surgery_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_surgery_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        surgery_index,
        surgery.age_at_surgery_months                                AS age_at_surgery_months,
        surgery.residual_tumor_area_cm2                              AS residual_tumor_area_cm2,
        surgery.residual_assessment_date                             AS residual_assessment_date,
        surgery.residual_assessment_date_precision                   AS residual_assessment_date_precision,
        CASE
            WHEN surgery.residual_assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(surgery.residual_assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(surgery.residual_assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(surgery.residual_assessment_date) = 4 OR surgery.residual_assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(surgery.residual_assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(surgery.residual_assessment_date) = 7 OR surgery.residual_assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(surgery.residual_assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(surgery.residual_assessment_date AS DATE)
        END AS residual_assessment_day,
        CASE
            WHEN surgery.residual_assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(surgery.residual_assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(surgery.residual_assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(surgery.residual_assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(surgery.residual_assessment_date) = 4 OR surgery.residual_assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(surgery.residual_assessment_date) = 7 OR surgery.residual_assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS residual_assessment_day_precision,
        surgery.surgery_type                                         AS surgery_type,
        surgery.extent_of_resection                                  AS extent_of_resection,
        surgery.surgery_date                                         AS surgery_date,
        surgery.surgery_date_precision                               AS surgery_date_precision,
        CASE
            WHEN surgery.surgery_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(surgery.surgery_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(surgery.surgery_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(surgery.surgery_date) = 4 OR surgery.surgery_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(surgery.surgery_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(surgery.surgery_date) = 7 OR surgery.surgery_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(surgery.surgery_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(surgery.surgery_date AS DATE)
        END AS surgery_day,
        CASE
            WHEN surgery.surgery_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(surgery.surgery_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(surgery.surgery_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(surgery.surgery_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(surgery.surgery_date) = 4 OR surgery.surgery_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(surgery.surgery_date) = 7 OR surgery.surgery_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS surgery_day_precision
FROM
        pcx__nlp_surgery_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.surgeries) WITH ORDINALITY AS surgery_t (surgery, surgery_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
