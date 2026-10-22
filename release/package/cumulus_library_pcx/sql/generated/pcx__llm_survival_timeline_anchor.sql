CREATE TABLE pcx__llm_survival_timeline_anchor AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_survival_timeline_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        anchor_index,
        anchor.anchor                                                AS anchor,
        anchor.anchor_date                                           AS anchor_date,
        anchor.anchor_date_precision                                 AS anchor_date_precision,
        CASE
            WHEN anchor.anchor_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(anchor.anchor_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(anchor.anchor_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(anchor.anchor_date) = 4 OR anchor.anchor_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(anchor.anchor_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(anchor.anchor_date) = 7 OR anchor.anchor_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(anchor.anchor_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(anchor.anchor_date AS DATE)
        END AS anchor_day,
        CASE
            WHEN anchor.anchor_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(anchor.anchor_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(anchor.anchor_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(anchor.anchor_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(anchor.anchor_date) = 4 OR anchor.anchor_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(anchor.anchor_date) = 7 OR anchor.anchor_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS anchor_day_precision,
        anchor.protocol_name                                         AS protocol_name
FROM
        pcx__nlp_survival_timeline_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.anchors) WITH ORDINALITY AS anchor_t (anchor, anchor_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
