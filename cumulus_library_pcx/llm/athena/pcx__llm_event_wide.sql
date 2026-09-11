CREATE TABLE pcx__llm_event_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_event_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        event_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        event.event_type                                             AS event_type,
        event.source_of_event_diagnosis                              AS source_of_event_diagnosis,
        event.event_date                                             AS event_date,
        event.event_date_precision                                   AS event_date_precision,
        event.date_of_progression_mri                                AS date_of_progression_mri,
        event.date_of_progression_mri_precision                      AS date_of_progression_mri_precision,
        event.confirmation_date                                      AS confirmation_date,
        event.confirmation_date_precision                            AS confirmation_date_precision
FROM
        pcx__nlp_event_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.events) WITH ORDINALITY AS event_t (event, event_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
