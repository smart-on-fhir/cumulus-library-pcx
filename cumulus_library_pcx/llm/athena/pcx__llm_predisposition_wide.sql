CREATE TABLE pcx__llm_predisposition_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_predisposition_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        finding_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        finding.gene_or_syndrome                                     AS gene_or_syndrome,
        finding.status                                               AS status,
        finding.variant_verbatim                                     AS variant_verbatim,
        finding.report_date                                          AS report_date,
        finding.report_date_precision                                AS report_date_precision
FROM
        pcx__nlp_predisposition_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.findings) WITH ORDINALITY AS finding_t (finding, finding_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
