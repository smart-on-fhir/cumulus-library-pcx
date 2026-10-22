CREATE TABLE pcx__llm_registry_eligibility_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_registry_eligibility_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        nlp.result.age_under_36_months_at_definitive_surgery.status                    AS age_under_36_months_at_definitive_surgery_status,
        nlp.result.age_under_36_months_at_definitive_surgery.assessment_date           AS age_under_36_months_at_definitive_surgery_assessment_date,
        nlp.result.age_under_36_months_at_definitive_surgery.assessment_date_precision AS age_under_36_months_at_definitive_surgery_assessment_date_precision,
        CASE
            WHEN nlp.result.age_under_36_months_at_definitive_surgery.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date) = 4 OR nlp.result.age_under_36_months_at_definitive_surgery.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date) = 7 OR nlp.result.age_under_36_months_at_definitive_surgery.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date AS DATE)
        END AS age_under_36_months_at_definitive_surgery_assessment_day,
        CASE
            WHEN nlp.result.age_under_36_months_at_definitive_surgery.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date) = 4 OR nlp.result.age_under_36_months_at_definitive_surgery.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.age_under_36_months_at_definitive_surgery.assessment_date) = 7 OR nlp.result.age_under_36_months_at_definitive_surgery.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS age_under_36_months_at_definitive_surgery_assessment_day_precision,
        nlp.result.newly_diagnosed_embryonal_tumor.status                              AS newly_diagnosed_embryonal_tumor_status,
        nlp.result.newly_diagnosed_embryonal_tumor.assessment_date                     AS newly_diagnosed_embryonal_tumor_assessment_date,
        nlp.result.newly_diagnosed_embryonal_tumor.assessment_date_precision           AS newly_diagnosed_embryonal_tumor_assessment_date_precision,
        CASE
            WHEN nlp.result.newly_diagnosed_embryonal_tumor.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date) = 4 OR nlp.result.newly_diagnosed_embryonal_tumor.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date) = 7 OR nlp.result.newly_diagnosed_embryonal_tumor.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date AS DATE)
        END AS newly_diagnosed_embryonal_tumor_assessment_day,
        CASE
            WHEN nlp.result.newly_diagnosed_embryonal_tumor.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date) = 4 OR nlp.result.newly_diagnosed_embryonal_tumor.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.newly_diagnosed_embryonal_tumor.assessment_date) = 7 OR nlp.result.newly_diagnosed_embryonal_tumor.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS newly_diagnosed_embryonal_tumor_assessment_day_precision,
        nlp.result.high_risk_disease.status                                            AS high_risk_disease_status,
        nlp.result.high_risk_disease.assessment_date                                   AS high_risk_disease_assessment_date,
        nlp.result.high_risk_disease.assessment_date_precision                         AS high_risk_disease_assessment_date_precision,
        CASE
            WHEN nlp.result.high_risk_disease.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.high_risk_disease.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.high_risk_disease.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.high_risk_disease.assessment_date) = 4 OR nlp.result.high_risk_disease.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.high_risk_disease.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.high_risk_disease.assessment_date) = 7 OR nlp.result.high_risk_disease.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.high_risk_disease.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.high_risk_disease.assessment_date AS DATE)
        END AS high_risk_disease_assessment_day,
        CASE
            WHEN nlp.result.high_risk_disease.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.high_risk_disease.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.high_risk_disease.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.high_risk_disease.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.high_risk_disease.assessment_date) = 4 OR nlp.result.high_risk_disease.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.high_risk_disease.assessment_date) = 7 OR nlp.result.high_risk_disease.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS high_risk_disease_assessment_day_precision,
        nlp.result.atrt_excluded.status                                                AS atrt_excluded_status,
        nlp.result.atrt_excluded.assessment_date                                       AS atrt_excluded_assessment_date,
        nlp.result.atrt_excluded.assessment_date_precision                             AS atrt_excluded_assessment_date_precision,
        CASE
            WHEN nlp.result.atrt_excluded.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.atrt_excluded.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.atrt_excluded.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.atrt_excluded.assessment_date) = 4 OR nlp.result.atrt_excluded.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.atrt_excluded.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.atrt_excluded.assessment_date) = 7 OR nlp.result.atrt_excluded.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.atrt_excluded.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.atrt_excluded.assessment_date AS DATE)
        END AS atrt_excluded_assessment_day,
        CASE
            WHEN nlp.result.atrt_excluded.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.atrt_excluded.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.atrt_excluded.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.atrt_excluded.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.atrt_excluded.assessment_date) = 4 OR nlp.result.atrt_excluded.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.atrt_excluded.assessment_date) = 7 OR nlp.result.atrt_excluded.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS atrt_excluded_assessment_day_precision,
        nlp.result.no_prior_chemotherapy.status                                        AS no_prior_chemotherapy_status,
        nlp.result.no_prior_chemotherapy.assessment_date                               AS no_prior_chemotherapy_assessment_date,
        nlp.result.no_prior_chemotherapy.assessment_date_precision                     AS no_prior_chemotherapy_assessment_date_precision,
        CASE
            WHEN nlp.result.no_prior_chemotherapy.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.no_prior_chemotherapy.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.no_prior_chemotherapy.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.no_prior_chemotherapy.assessment_date) = 4 OR nlp.result.no_prior_chemotherapy.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.no_prior_chemotherapy.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.no_prior_chemotherapy.assessment_date) = 7 OR nlp.result.no_prior_chemotherapy.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.no_prior_chemotherapy.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.no_prior_chemotherapy.assessment_date AS DATE)
        END AS no_prior_chemotherapy_assessment_day,
        CASE
            WHEN nlp.result.no_prior_chemotherapy.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.no_prior_chemotherapy.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.no_prior_chemotherapy.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.no_prior_chemotherapy.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.no_prior_chemotherapy.assessment_date) = 4 OR nlp.result.no_prior_chemotherapy.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.no_prior_chemotherapy.assessment_date) = 7 OR nlp.result.no_prior_chemotherapy.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS no_prior_chemotherapy_assessment_day_precision,
        nlp.result.no_prior_radiation.status                                           AS no_prior_radiation_status,
        nlp.result.no_prior_radiation.assessment_date                                  AS no_prior_radiation_assessment_date,
        nlp.result.no_prior_radiation.assessment_date_precision                        AS no_prior_radiation_assessment_date_precision,
        CASE
            WHEN nlp.result.no_prior_radiation.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.no_prior_radiation.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.no_prior_radiation.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.no_prior_radiation.assessment_date) = 4 OR nlp.result.no_prior_radiation.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.no_prior_radiation.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.no_prior_radiation.assessment_date) = 7 OR nlp.result.no_prior_radiation.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.no_prior_radiation.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.no_prior_radiation.assessment_date AS DATE)
        END AS no_prior_radiation_assessment_day,
        CASE
            WHEN nlp.result.no_prior_radiation.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.no_prior_radiation.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.no_prior_radiation.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.no_prior_radiation.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.no_prior_radiation.assessment_date) = 4 OR nlp.result.no_prior_radiation.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.no_prior_radiation.assessment_date) = 7 OR nlp.result.no_prior_radiation.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS no_prior_radiation_assessment_day_precision,
        nlp.result.adequate_renal_function.status                                      AS adequate_renal_function_status,
        nlp.result.adequate_renal_function.assessment_date                             AS adequate_renal_function_assessment_date,
        nlp.result.adequate_renal_function.assessment_date_precision                   AS adequate_renal_function_assessment_date_precision,
        CASE
            WHEN nlp.result.adequate_renal_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_renal_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_renal_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_renal_function.assessment_date) = 4 OR nlp.result.adequate_renal_function.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_renal_function.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.adequate_renal_function.assessment_date) = 7 OR nlp.result.adequate_renal_function.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_renal_function.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.adequate_renal_function.assessment_date AS DATE)
        END AS adequate_renal_function_assessment_day,
        CASE
            WHEN nlp.result.adequate_renal_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_renal_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_renal_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_renal_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_renal_function.assessment_date) = 4 OR nlp.result.adequate_renal_function.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.adequate_renal_function.assessment_date) = 7 OR nlp.result.adequate_renal_function.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS adequate_renal_function_assessment_day_precision,
        nlp.result.adequate_hepatic_function.status                                    AS adequate_hepatic_function_status,
        nlp.result.adequate_hepatic_function.assessment_date                           AS adequate_hepatic_function_assessment_date,
        nlp.result.adequate_hepatic_function.assessment_date_precision                 AS adequate_hepatic_function_assessment_date_precision,
        CASE
            WHEN nlp.result.adequate_hepatic_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_hepatic_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_hepatic_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_hepatic_function.assessment_date) = 4 OR nlp.result.adequate_hepatic_function.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_hepatic_function.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.adequate_hepatic_function.assessment_date) = 7 OR nlp.result.adequate_hepatic_function.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_hepatic_function.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.adequate_hepatic_function.assessment_date AS DATE)
        END AS adequate_hepatic_function_assessment_day,
        CASE
            WHEN nlp.result.adequate_hepatic_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_hepatic_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_hepatic_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_hepatic_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_hepatic_function.assessment_date) = 4 OR nlp.result.adequate_hepatic_function.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.adequate_hepatic_function.assessment_date) = 7 OR nlp.result.adequate_hepatic_function.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS adequate_hepatic_function_assessment_day_precision,
        nlp.result.adequate_cardiac_function.status                                    AS adequate_cardiac_function_status,
        nlp.result.adequate_cardiac_function.assessment_date                           AS adequate_cardiac_function_assessment_date,
        nlp.result.adequate_cardiac_function.assessment_date_precision                 AS adequate_cardiac_function_assessment_date_precision,
        CASE
            WHEN nlp.result.adequate_cardiac_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_cardiac_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_cardiac_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_cardiac_function.assessment_date) = 4 OR nlp.result.adequate_cardiac_function.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_cardiac_function.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.adequate_cardiac_function.assessment_date) = 7 OR nlp.result.adequate_cardiac_function.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_cardiac_function.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.adequate_cardiac_function.assessment_date AS DATE)
        END AS adequate_cardiac_function_assessment_day,
        CASE
            WHEN nlp.result.adequate_cardiac_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_cardiac_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_cardiac_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_cardiac_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_cardiac_function.assessment_date) = 4 OR nlp.result.adequate_cardiac_function.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.adequate_cardiac_function.assessment_date) = 7 OR nlp.result.adequate_cardiac_function.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS adequate_cardiac_function_assessment_day_precision,
        nlp.result.adequate_pulmonary_function.status                                  AS adequate_pulmonary_function_status,
        nlp.result.adequate_pulmonary_function.assessment_date                         AS adequate_pulmonary_function_assessment_date,
        nlp.result.adequate_pulmonary_function.assessment_date_precision               AS adequate_pulmonary_function_assessment_date_precision,
        CASE
            WHEN nlp.result.adequate_pulmonary_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_pulmonary_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_pulmonary_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_pulmonary_function.assessment_date) = 4 OR nlp.result.adequate_pulmonary_function.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_pulmonary_function.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.adequate_pulmonary_function.assessment_date) = 7 OR nlp.result.adequate_pulmonary_function.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_pulmonary_function.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.adequate_pulmonary_function.assessment_date AS DATE)
        END AS adequate_pulmonary_function_assessment_day,
        CASE
            WHEN nlp.result.adequate_pulmonary_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_pulmonary_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_pulmonary_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_pulmonary_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_pulmonary_function.assessment_date) = 4 OR nlp.result.adequate_pulmonary_function.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.adequate_pulmonary_function.assessment_date) = 7 OR nlp.result.adequate_pulmonary_function.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS adequate_pulmonary_function_assessment_day_precision,
        nlp.result.adequate_marrow_function.status                                     AS adequate_marrow_function_status,
        nlp.result.adequate_marrow_function.assessment_date                            AS adequate_marrow_function_assessment_date,
        nlp.result.adequate_marrow_function.assessment_date_precision                  AS adequate_marrow_function_assessment_date_precision,
        CASE
            WHEN nlp.result.adequate_marrow_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_marrow_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_marrow_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_marrow_function.assessment_date) = 4 OR nlp.result.adequate_marrow_function.assessment_date_precision = 'YEAR'     THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_marrow_function.assessment_date, 1, 4), '-01-01') AS DATE)
            WHEN LENGTH(nlp.result.adequate_marrow_function.assessment_date) = 7 OR nlp.result.adequate_marrow_function.assessment_date_precision = 'MONTH'    THEN CAST(CONCAT(SUBSTR(nlp.result.adequate_marrow_function.assessment_date, 1, 7), '-01') AS DATE)
            ELSE                                                             CAST(nlp.result.adequate_marrow_function.assessment_date AS DATE)
        END AS adequate_marrow_function_assessment_day,
        CASE
            WHEN nlp.result.adequate_marrow_function.assessment_date IS NULL                                    THEN NULL
            WHEN NOT (REGEXP_LIKE(nlp.result.adequate_marrow_function.assessment_date, '^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$')
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10), 6, 2) BETWEEN '01' AND '12'
            AND SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10), 9, 2) BETWEEN '01' AND
                CASE
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10), 6, 2) IN ('04', '06', '09', '11')    THEN '30'
                    WHEN SUBSTR(SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10), 6, 2) <> '02'                        THEN '31'
                    WHEN REGEXP_LIKE(SUBSTR(nlp.result.adequate_marrow_function.assessment_date, 1, 4), '^([0-9]{2}(0[48]|[2468][048]|[13579][26])|([02468][048]|[13579][26])00)$')          THEN '29'
                    ELSE                                                                       '28'
                END)                            THEN NULL
            WHEN NOT (SUBSTR(CONCAT(nlp.result.adequate_marrow_function.assessment_date, '-01-01'), 1, 10) BETWEEN '1980-01-01' AND CAST(CURRENT_DATE AS VARCHAR))                             THEN NULL
            WHEN LENGTH(nlp.result.adequate_marrow_function.assessment_date) = 4 OR nlp.result.adequate_marrow_function.assessment_date_precision = 'YEAR'     THEN 'YEAR'
            WHEN LENGTH(nlp.result.adequate_marrow_function.assessment_date) = 7 OR nlp.result.adequate_marrow_function.assessment_date_precision = 'MONTH'    THEN 'MONTH'
            ELSE                                                             'DAY'
        END AS adequate_marrow_function_assessment_day_precision
FROM
        pcx__nlp_registry_eligibility_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
