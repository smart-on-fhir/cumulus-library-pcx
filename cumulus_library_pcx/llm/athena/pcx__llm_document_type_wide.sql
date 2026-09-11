CREATE TABLE pcx__llm_document_type_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_document_type_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- mention values only: spans and has_mention stay in the source nlp table
        nlp.result.document_type.document_type                       AS document_type,
        nlp.result.document_type.confidence                          AS confidence
FROM
        pcx__nlp_document_type_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
