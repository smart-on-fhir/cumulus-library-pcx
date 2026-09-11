CREATE TABLE pcx__llm_laboratory_toxicity AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_laboratory_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        toxicity_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        toxicity.toxicity                                            AS toxicity,
        toxicity.grade                                               AS grade,
        toxicity.grading_system                                      AS grading_system,
        toxicity.phase                                               AS phase,
        toxicity.event_date                                          AS event_date,
        toxicity.event_date_precision                                AS event_date_precision,
        toxicity.attribution                                         AS attribution
FROM
        pcx__nlp_laboratory_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.toxicities) WITH ORDINALITY AS toxicity_t (toxicity, toxicity_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
