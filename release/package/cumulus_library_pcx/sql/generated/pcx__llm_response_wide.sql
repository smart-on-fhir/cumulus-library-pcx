CREATE TABLE pcx__llm_response_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_response_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        assessment_index,
        assessment.timepoint                                         AS timepoint,
        assessment.response                                          AS response,
        assessment.radiologically_evaluable                          AS radiologically_evaluable,
        assessment.cytologically_evaluable                           AS cytologically_evaluable,
        assessment.assessment_date                                   AS assessment_date,
        assessment.assessment_date_precision                         AS assessment_date_precision,
        CASE
            WHEN assessment.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(assessment.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(assessment.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(assessment.assessment_date) = 4 OR assessment.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(assessment.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(assessment.assessment_date) = 7 OR assessment.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(assessment.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(assessment.assessment_date AS DATE)
        END AS assessment_day,
        CASE
            WHEN assessment.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(assessment.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(assessment.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(assessment.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(assessment.assessment_date) = 4 OR assessment.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(assessment.assessment_date) = 7 OR assessment.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS assessment_day_precision
FROM
        pcx__nlp_response_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.assessments) WITH ORDINALITY AS assessment_t (assessment, assessment_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
