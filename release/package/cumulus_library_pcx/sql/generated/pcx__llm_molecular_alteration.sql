CREATE TABLE pcx__llm_molecular_alteration AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_molecular_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        alteration_index,
        alteration.target                                            AS target,
        alteration.alteration                                        AS alteration,
        alteration.status                                            AS status,
        alteration.report_date                                       AS report_date,
        alteration.report_date_precision                             AS report_date_precision,
        alteration.testing_method                                    AS testing_method
FROM
        pcx__nlp_molecular_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.alterations) WITH ORDINALITY AS alteration_t (alteration, alteration_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
