CREATE TABLE pcx__llm_laboratory_result AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_laboratory_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        result_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        result.test                                                  AS test,
        result.result_verbatim                                       AS result_verbatim,
        result.value                                                 AS value,
        result.units                                                 AS units,
        result.reference_range                                       AS reference_range,
        result.collection_date                                       AS collection_date,
        result.collection_date_precision                             AS collection_date_precision,
        result.context                                               AS context
FROM
        pcx__nlp_laboratory_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.results) WITH ORDINALITY AS result_t (result, result_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
