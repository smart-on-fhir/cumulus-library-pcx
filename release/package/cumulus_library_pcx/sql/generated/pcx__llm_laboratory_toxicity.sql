CREATE TABLE pcx__llm_laboratory_toxicity AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_laboratory_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        toxicity_index,
        toxicity.toxicity                                            AS toxicity,
        toxicity.grade                                               AS grade,
        toxicity.grading_system                                      AS grading_system,
        toxicity.phase                                               AS phase,
        toxicity.event_date                                          AS event_date,
        toxicity.event_date_precision                                AS event_date_precision,
        CASE
            WHEN toxicity.event_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(toxicity.event_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(toxicity.event_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(toxicity.event_date) = 4 OR toxicity.event_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(toxicity.event_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(toxicity.event_date) = 7 OR toxicity.event_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(toxicity.event_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(toxicity.event_date AS DATE)
        END AS event_day,
        CASE
            WHEN toxicity.event_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(toxicity.event_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(toxicity.event_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(toxicity.event_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(toxicity.event_date) = 4 OR toxicity.event_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(toxicity.event_date) = 7 OR toxicity.event_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS event_day_precision,
        toxicity.attribution                                         AS attribution
FROM
        pcx__nlp_laboratory_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.toxicities) WITH ORDINALITY AS toxicity_t (toxicity, toxicity_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 3
