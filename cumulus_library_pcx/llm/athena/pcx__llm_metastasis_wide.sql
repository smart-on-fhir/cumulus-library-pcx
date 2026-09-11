CREATE TABLE pcx__llm_metastasis_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_metastasis_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- mention values only: spans and has_mention stay in the source nlp table
        nlp.result.staging_inputs.csf_collection_site                AS csf_collection_site,
        nlp.result.staging_inputs.csf_collection_date                AS csf_collection_date,
        nlp.result.staging_inputs.csf_collection_date_precision      AS csf_collection_date_precision,
        nlp.result.staging_inputs.brain_mri_date                     AS brain_mri_date,
        nlp.result.staging_inputs.brain_mri_date_precision           AS brain_mri_date_precision,
        nlp.result.staging_inputs.spine_mri_date                     AS spine_mri_date,
        nlp.result.staging_inputs.spine_mri_date_precision           AS spine_mri_date_precision,
        nlp.result.staging_inputs.spine_mri_findings                 AS spine_mri_findings,
        nlp.result.staging_inputs.brain_mri_findings                 AS brain_mri_findings,
        nlp.result.staging_inputs.csf_cytology                       AS csf_cytology,
        nlp.result.staging_inputs.extraneural_metastasis             AS extraneural_metastasis
FROM
        pcx__nlp_metastasis_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
