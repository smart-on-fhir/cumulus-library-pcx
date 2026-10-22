CREATE TABLE pcx__llm_transition_of_care_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_transition_of_care_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        nlp.result.transfer_in.transfer_in_timing                                   AS transfer_in_timing,
        nlp.result.transfer_in.transfer_in_date                                     AS transfer_in_date,
        nlp.result.transfer_in.transfer_in_date_precision                           AS transfer_in_date_precision,
        CASE
            WHEN nlp.result.transfer_in.transfer_in_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.transfer_in.transfer_in_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.transfer_in.transfer_in_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.transfer_in.transfer_in_date) = 4 OR nlp.result.transfer_in.transfer_in_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.transfer_in.transfer_in_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.transfer_in.transfer_in_date) = 7 OR nlp.result.transfer_in.transfer_in_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.transfer_in.transfer_in_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.transfer_in.transfer_in_date AS DATE)
        END AS transfer_in_day,
        CASE
            WHEN nlp.result.transfer_in.transfer_in_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.transfer_in.transfer_in_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.transfer_in.transfer_in_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.transfer_in.transfer_in_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.transfer_in.transfer_in_date) = 4 OR nlp.result.transfer_in.transfer_in_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.transfer_in.transfer_in_date) = 7 OR nlp.result.transfer_in.transfer_in_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS transfer_in_day_precision,
        nlp.result.transfer_in.transfer_in_reason                                   AS transfer_in_reason,
        nlp.result.diagnosis_setting.diagnosis_setting                              AS diagnosis_setting,
        nlp.result.diagnosis_setting.imaging_detected_externally                    AS imaging_detected_externally,
        nlp.result.definitive_surgery_setting.surgery_setting                       AS surgery_setting,
        nlp.result.prior_therapy_at_entry.prior_therapy_exposure                    AS prior_therapy_exposure,
        array_join(nlp.result.prior_therapy_at_entry.prior_therapy_modalities, ',') AS prior_therapy_modalities
FROM
        pcx__nlp_transition_of_care_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
