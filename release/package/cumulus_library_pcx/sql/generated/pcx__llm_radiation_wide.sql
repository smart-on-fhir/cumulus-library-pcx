CREATE TABLE pcx__llm_radiation_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_radiation_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        radiation_round_index,
        radiation_round.delivery_status                              AS delivery_status,
        radiation_round.phase                                        AS phase,
        radiation_round.indication                                   AS indication,
        radiation_round.assessed_through_date                        AS assessed_through_date,
        radiation_round.assessed_through_date_precision              AS assessed_through_date_precision,
        CASE
            WHEN radiation_round.assessed_through_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(radiation_round.assessed_through_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(radiation_round.assessed_through_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(radiation_round.assessed_through_date) = 4 OR radiation_round.assessed_through_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(radiation_round.assessed_through_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(radiation_round.assessed_through_date) = 7 OR radiation_round.assessed_through_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(radiation_round.assessed_through_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(radiation_round.assessed_through_date AS DATE)
        END AS assessed_through_day,
        CASE
            WHEN radiation_round.assessed_through_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(radiation_round.assessed_through_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(radiation_round.assessed_through_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(radiation_round.assessed_through_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(radiation_round.assessed_through_date) = 4 OR radiation_round.assessed_through_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(radiation_round.assessed_through_date) = 7 OR radiation_round.assessed_through_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS assessed_through_day_precision,
        radiation_round.dose_verbatim                                AS dose_verbatim,
        radiation_round.radiation_method                             AS radiation_method,
        radiation_round.radiation_field                              AS radiation_field,
        radiation_round.radiation_start_date                         AS radiation_start_date,
        radiation_round.radiation_start_date_precision               AS radiation_start_date_precision,
        CASE
            WHEN radiation_round.radiation_start_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(radiation_round.radiation_start_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(radiation_round.radiation_start_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(radiation_round.radiation_start_date) = 4 OR radiation_round.radiation_start_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(radiation_round.radiation_start_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(radiation_round.radiation_start_date) = 7 OR radiation_round.radiation_start_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(radiation_round.radiation_start_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(radiation_round.radiation_start_date AS DATE)
        END AS radiation_start_day,
        CASE
            WHEN radiation_round.radiation_start_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(radiation_round.radiation_start_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(radiation_round.radiation_start_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(radiation_round.radiation_start_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(radiation_round.radiation_start_date) = 4 OR radiation_round.radiation_start_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(radiation_round.radiation_start_date) = 7 OR radiation_round.radiation_start_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS radiation_start_day_precision,
        radiation_round.radiation_end_date                           AS radiation_end_date,
        radiation_round.radiation_end_date_precision                 AS radiation_end_date_precision,
        CASE
            WHEN radiation_round.radiation_end_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(radiation_round.radiation_end_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(radiation_round.radiation_end_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(radiation_round.radiation_end_date) = 4 OR radiation_round.radiation_end_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(radiation_round.radiation_end_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(radiation_round.radiation_end_date) = 7 OR radiation_round.radiation_end_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(radiation_round.radiation_end_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(radiation_round.radiation_end_date AS DATE)
        END AS radiation_end_day,
        CASE
            WHEN radiation_round.radiation_end_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(radiation_round.radiation_end_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(radiation_round.radiation_end_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(radiation_round.radiation_end_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(radiation_round.radiation_end_date) = 4 OR radiation_round.radiation_end_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(radiation_round.radiation_end_date) = 7 OR radiation_round.radiation_end_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS radiation_end_day_precision,
        radiation_round.focal_dose_to_primary_site                   AS focal_dose_to_primary_site,
        radiation_round.total_dose_to_primary_site                   AS total_dose_to_primary_site,
        radiation_round.focal_dose_to_metastatic_site                AS focal_dose_to_metastatic_site,
        radiation_round.total_dose_to_metastatic_site                AS total_dose_to_metastatic_site,
        radiation_round.craniospinal_dose                            AS craniospinal_dose,
        radiation_round.whole_ventricular_dose                       AS whole_ventricular_dose,
        radiation_round.dose_units                                   AS dose_units
FROM
        pcx__nlp_radiation_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.radiation_rounds) WITH ORDINALITY AS radiation_round_t (radiation_round, radiation_round_index)
WHERE
        nlp.result IS NOT NULL
-- The NLP table holds ONE task version, the folder it was last built over. Version 3
-- changed only the TreatmentPhase wording, not the schema shape, so this reads either.
-- Nothing keeps version 2 rows beside version 3 rows: rebuilding the radiation task
-- repoints the table at version 3 and re-extracts every note.
AND     nlp.task_version IN (2, 3)
