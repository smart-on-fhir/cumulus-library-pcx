CREATE TABLE pcx__llm_patient_anchor AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_patient_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        anchor_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        anchor.anchor                                                AS anchor,
        anchor.anchor_date                                           AS anchor_date,
        anchor.anchor_date_precision                                 AS anchor_date_precision,
        anchor.protocol_name                                         AS protocol_name
FROM
        pcx__nlp_patient_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.anchors) WITH ORDINALITY AS anchor_t (anchor, anchor_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
