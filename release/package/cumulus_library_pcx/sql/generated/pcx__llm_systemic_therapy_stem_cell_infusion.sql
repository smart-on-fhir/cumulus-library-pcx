CREATE TABLE pcx__llm_systemic_therapy_stem_cell_infusion AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_systemic_therapy_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        stem_cell_infusion_index,
        stem_cell_infusion.delivery_status                           AS delivery_status,
        stem_cell_infusion.phase                                     AS phase,
        stem_cell_infusion.infusion_date                             AS infusion_date,
        stem_cell_infusion.infusion_date_precision                   AS infusion_date_precision,
        CASE
            WHEN stem_cell_infusion.infusion_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(stem_cell_infusion.infusion_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(stem_cell_infusion.infusion_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(stem_cell_infusion.infusion_date) = 4 OR stem_cell_infusion.infusion_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(stem_cell_infusion.infusion_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(stem_cell_infusion.infusion_date) = 7 OR stem_cell_infusion.infusion_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(stem_cell_infusion.infusion_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(stem_cell_infusion.infusion_date AS DATE)
        END AS infusion_day,
        CASE
            WHEN stem_cell_infusion.infusion_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(stem_cell_infusion.infusion_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(stem_cell_infusion.infusion_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(stem_cell_infusion.infusion_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(stem_cell_infusion.infusion_date) = 4 OR stem_cell_infusion.infusion_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(stem_cell_infusion.infusion_date) = 7 OR stem_cell_infusion.infusion_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS infusion_day_precision,
        stem_cell_infusion.cycle_num                                 AS cycle_num,
        stem_cell_infusion.cycle_name_verbatim                       AS cycle_name_verbatim,
        stem_cell_infusion.cell_source                               AS cell_source,
        stem_cell_infusion.cd34_cells_per_kg                         AS cd34_cells_per_kg
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.stem_cell_infusions) WITH ORDINALITY AS stem_cell_infusion_t (stem_cell_infusion, stem_cell_infusion_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
