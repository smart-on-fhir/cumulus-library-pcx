CREATE TABLE pcx__llm_metastasis_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_metastasis_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        nlp.result.staging_inputs.csf_collection_date                AS csf_collection_date,
        nlp.result.staging_inputs.csf_collection_date_precision      AS csf_collection_date_precision,
        CASE
            WHEN nlp.result.staging_inputs.csf_collection_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.staging_inputs.csf_collection_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.staging_inputs.csf_collection_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.staging_inputs.csf_collection_date) = 4 OR nlp.result.staging_inputs.csf_collection_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.staging_inputs.csf_collection_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.staging_inputs.csf_collection_date) = 7 OR nlp.result.staging_inputs.csf_collection_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.staging_inputs.csf_collection_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.staging_inputs.csf_collection_date AS DATE)
        END AS csf_collection_day,
        CASE
            WHEN nlp.result.staging_inputs.csf_collection_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.staging_inputs.csf_collection_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.staging_inputs.csf_collection_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.staging_inputs.csf_collection_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.staging_inputs.csf_collection_date) = 4 OR nlp.result.staging_inputs.csf_collection_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.staging_inputs.csf_collection_date) = 7 OR nlp.result.staging_inputs.csf_collection_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS csf_collection_day_precision,
        nlp.result.staging_inputs.brain_mri_date                     AS brain_mri_date,
        nlp.result.staging_inputs.brain_mri_date_precision           AS brain_mri_date_precision,
        CASE
            WHEN nlp.result.staging_inputs.brain_mri_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.staging_inputs.brain_mri_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.staging_inputs.brain_mri_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.staging_inputs.brain_mri_date) = 4 OR nlp.result.staging_inputs.brain_mri_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.staging_inputs.brain_mri_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.staging_inputs.brain_mri_date) = 7 OR nlp.result.staging_inputs.brain_mri_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.staging_inputs.brain_mri_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.staging_inputs.brain_mri_date AS DATE)
        END AS brain_mri_day,
        CASE
            WHEN nlp.result.staging_inputs.brain_mri_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.staging_inputs.brain_mri_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.staging_inputs.brain_mri_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.staging_inputs.brain_mri_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.staging_inputs.brain_mri_date) = 4 OR nlp.result.staging_inputs.brain_mri_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.staging_inputs.brain_mri_date) = 7 OR nlp.result.staging_inputs.brain_mri_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS brain_mri_day_precision,
        nlp.result.staging_inputs.spine_mri_date                     AS spine_mri_date,
        nlp.result.staging_inputs.spine_mri_date_precision           AS spine_mri_date_precision,
        CASE
            WHEN nlp.result.staging_inputs.spine_mri_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.staging_inputs.spine_mri_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.staging_inputs.spine_mri_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.staging_inputs.spine_mri_date) = 4 OR nlp.result.staging_inputs.spine_mri_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.staging_inputs.spine_mri_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.staging_inputs.spine_mri_date) = 7 OR nlp.result.staging_inputs.spine_mri_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.staging_inputs.spine_mri_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.staging_inputs.spine_mri_date AS DATE)
        END AS spine_mri_day,
        CASE
            WHEN nlp.result.staging_inputs.spine_mri_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.staging_inputs.spine_mri_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.staging_inputs.spine_mri_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.staging_inputs.spine_mri_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.staging_inputs.spine_mri_date) = 4 OR nlp.result.staging_inputs.spine_mri_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.staging_inputs.spine_mri_date) = 7 OR nlp.result.staging_inputs.spine_mri_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS spine_mri_day_precision,
        nlp.result.staging_inputs.spine_mri_findings                 AS spine_mri_findings,
        nlp.result.staging_inputs.brain_mri_findings                 AS brain_mri_findings,
        nlp.result.staging_inputs.csf_cytology                       AS csf_cytology,
        nlp.result.staging_inputs.extraneural_metastasis             AS extraneural_metastasis
FROM
        pcx__nlp_metastasis_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
