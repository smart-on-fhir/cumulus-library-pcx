CREATE TABLE pcx__llm_registry_eligibility_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_registry_eligibility_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- mention values only: spans and has_mention stay in the source nlp table
        nlp.result.age_under_36_months_at_definitive_surgery.status                    AS age_under_36_months_at_definitive_surgery_status,
        nlp.result.age_under_36_months_at_definitive_surgery.assessment_date           AS age_under_36_months_at_definitive_surgery_assessment_date,
        nlp.result.age_under_36_months_at_definitive_surgery.assessment_date_precision AS age_under_36_months_at_definitive_surgery_assessment_date_precision,
        nlp.result.newly_diagnosed_embryonal_tumor.status                              AS newly_diagnosed_embryonal_tumor_status,
        nlp.result.newly_diagnosed_embryonal_tumor.assessment_date                     AS newly_diagnosed_embryonal_tumor_assessment_date,
        nlp.result.newly_diagnosed_embryonal_tumor.assessment_date_precision           AS newly_diagnosed_embryonal_tumor_assessment_date_precision,
        nlp.result.high_risk_disease.status                                            AS high_risk_disease_status,
        nlp.result.high_risk_disease.assessment_date                                   AS high_risk_disease_assessment_date,
        nlp.result.high_risk_disease.assessment_date_precision                         AS high_risk_disease_assessment_date_precision,
        nlp.result.atrt_excluded.status                                                AS atrt_excluded_status,
        nlp.result.atrt_excluded.assessment_date                                       AS atrt_excluded_assessment_date,
        nlp.result.atrt_excluded.assessment_date_precision                             AS atrt_excluded_assessment_date_precision,
        nlp.result.no_prior_chemotherapy.status                                        AS no_prior_chemotherapy_status,
        nlp.result.no_prior_chemotherapy.assessment_date                               AS no_prior_chemotherapy_assessment_date,
        nlp.result.no_prior_chemotherapy.assessment_date_precision                     AS no_prior_chemotherapy_assessment_date_precision,
        nlp.result.no_prior_radiation.status                                           AS no_prior_radiation_status,
        nlp.result.no_prior_radiation.assessment_date                                  AS no_prior_radiation_assessment_date,
        nlp.result.no_prior_radiation.assessment_date_precision                        AS no_prior_radiation_assessment_date_precision,
        nlp.result.adequate_renal_function.status                                      AS adequate_renal_function_status,
        nlp.result.adequate_renal_function.assessment_date                             AS adequate_renal_function_assessment_date,
        nlp.result.adequate_renal_function.assessment_date_precision                   AS adequate_renal_function_assessment_date_precision,
        nlp.result.adequate_hepatic_function.status                                    AS adequate_hepatic_function_status,
        nlp.result.adequate_hepatic_function.assessment_date                           AS adequate_hepatic_function_assessment_date,
        nlp.result.adequate_hepatic_function.assessment_date_precision                 AS adequate_hepatic_function_assessment_date_precision,
        nlp.result.adequate_cardiac_function.status                                    AS adequate_cardiac_function_status,
        nlp.result.adequate_cardiac_function.assessment_date                           AS adequate_cardiac_function_assessment_date,
        nlp.result.adequate_cardiac_function.assessment_date_precision                 AS adequate_cardiac_function_assessment_date_precision,
        nlp.result.adequate_pulmonary_function.status                                  AS adequate_pulmonary_function_status,
        nlp.result.adequate_pulmonary_function.assessment_date                         AS adequate_pulmonary_function_assessment_date,
        nlp.result.adequate_pulmonary_function.assessment_date_precision               AS adequate_pulmonary_function_assessment_date_precision,
        nlp.result.adequate_marrow_function.status                                     AS adequate_marrow_function_status,
        nlp.result.adequate_marrow_function.assessment_date                            AS adequate_marrow_function_assessment_date,
        nlp.result.adequate_marrow_function.assessment_date_precision                  AS adequate_marrow_function_assessment_date_precision
FROM
        pcx__nlp_registry_eligibility_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
