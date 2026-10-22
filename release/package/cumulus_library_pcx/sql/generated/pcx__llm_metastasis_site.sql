CREATE TABLE pcx__llm_metastasis_site AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_metastasis_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        metastasis_site_index,
        metastasis_site.site                                         AS site,
        metastasis_site.site_date                                    AS site_date,
        metastasis_site.site_date_precision                          AS site_date_precision,
        CASE
            WHEN metastasis_site.site_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(metastasis_site.site_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(metastasis_site.site_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(metastasis_site.site_date) = 4 OR metastasis_site.site_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(metastasis_site.site_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(metastasis_site.site_date) = 7 OR metastasis_site.site_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(metastasis_site.site_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(metastasis_site.site_date AS DATE)
        END AS site_day,
        CASE
            WHEN metastasis_site.site_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(metastasis_site.site_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(metastasis_site.site_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(metastasis_site.site_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(metastasis_site.site_date) = 4 OR metastasis_site.site_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(metastasis_site.site_date) = 7 OR metastasis_site.site_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS site_day_precision
FROM
        pcx__nlp_metastasis_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.metastasis_sites) WITH ORDINALITY AS metastasis_site_t (metastasis_site, metastasis_site_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
