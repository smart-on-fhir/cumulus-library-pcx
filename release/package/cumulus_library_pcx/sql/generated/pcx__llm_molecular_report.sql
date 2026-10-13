CREATE TABLE pcx__llm_molecular_report AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_molecular_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        report_index,
        report.molecular_group                                       AS molecular_group,
        array_join(report.methods, ',')                              AS methods,
        report.report_date                                           AS report_date,
        report.report_date_precision                                 AS report_date_precision
FROM
        pcx__nlp_molecular_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.reports) WITH ORDINALITY AS report_t (report, report_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 2
