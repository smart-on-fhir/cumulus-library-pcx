CREATE TABLE pcx__llm_patient_follow_up AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_patient_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        follow_up_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        follow_up.event_free                                         AS event_free,
        follow_up.assessment_date                                    AS assessment_date,
        follow_up.assessment_date_precision                          AS assessment_date_precision,
        follow_up.assessment_method                                  AS assessment_method
FROM
        pcx__nlp_patient_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.event_free_follow_up) WITH ORDINALITY AS follow_up_t (follow_up, follow_up_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
