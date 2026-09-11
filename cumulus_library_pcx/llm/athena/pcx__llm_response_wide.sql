CREATE TABLE pcx__llm_response_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_response_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        assessment_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        assessment.timepoint                                         AS timepoint,
        assessment.response                                          AS response,
        assessment.radiologically_evaluable                          AS radiologically_evaluable,
        assessment.cytologically_evaluable                           AS cytologically_evaluable,
        assessment.assessment_date                                   AS assessment_date,
        assessment.assessment_date_precision                         AS assessment_date_precision,
        assessment.assessment_method                                 AS assessment_method,
        assessment.review_context                                    AS review_context
FROM
        pcx__nlp_response_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.assessments) WITH ORDINALITY AS assessment_t (assessment, assessment_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
