CREATE TABLE pcx__llm_patient_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_patient_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- mention values only: spans and has_mention stay in the source nlp table
        nlp.result.vital_status.vital_status                         AS vital_status,
        nlp.result.vital_status.death_date                           AS death_date,
        nlp.result.vital_status.death_date_precision                 AS death_date_precision,
        nlp.result.vital_status.last_known_alive_date                AS last_known_alive_date,
        nlp.result.vital_status.last_known_alive_date_precision      AS last_known_alive_date_precision
FROM
        pcx__nlp_patient_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
