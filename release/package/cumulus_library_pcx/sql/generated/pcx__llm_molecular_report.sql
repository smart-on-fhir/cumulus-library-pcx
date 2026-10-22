CREATE TABLE pcx__llm_molecular_report AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_molecular_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        report_index,
        report.molecular_group                                       AS molecular_group,
        array_join(report.methods, ',')                              AS methods,
        report.report_date                                           AS report_date,
        report.report_date_precision                                 AS report_date_precision,
        CASE
            WHEN report.report_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(report.report_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(report.report_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(report.report_date) = 4 OR report.report_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(report.report_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(report.report_date) = 7 OR report.report_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(report.report_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(report.report_date AS DATE)
        END AS report_day,
        CASE
            WHEN report.report_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(report.report_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(report.report_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(report.report_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(report.report_date) = 4 OR report.report_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(report.report_date) = 7 OR report.report_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS report_day_precision
FROM
        pcx__nlp_molecular_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.reports) WITH ORDINALITY AS report_t (report, report_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
