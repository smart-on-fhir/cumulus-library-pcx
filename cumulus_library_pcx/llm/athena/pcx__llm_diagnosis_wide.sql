CREATE TABLE pcx__llm_diagnosis_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_diagnosis_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- mention values only: spans and has_mention stay in the source nlp table
        nlp.result.disease_subtype.disease_subtype                          AS disease_subtype,
        nlp.result.medulloblastoma_histology.histology                      AS medulloblastoma_histology,
        nlp.result.disease_subtype.historical_diagnosis_term           AS historical_diagnosis_term,
        nlp.result.tumor_location.tumor_location_verbatim                   AS tumor_location_verbatim,
        nlp.result.chang_m_stage.chang_m_stage                              AS chang_m_stage,
        nlp.result.age_at_diagnosis.age_at_diagnosis_months                 AS age_at_diagnosis_months,
        nlp.result.diagnosis_date.diagnosis_date                            AS diagnosis_date,
        nlp.result.diagnosis_date.diagnosis_date_precision                  AS diagnosis_date_precision,
        nlp.result.diagnosis_date_gold.diagnosis_date_gold                  AS diagnosis_date_gold,
        nlp.result.diagnosis_date_gold.diagnosis_date_gold_precision        AS diagnosis_date_gold_precision
FROM
        pcx__nlp_diagnosis_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     task_version = 2
