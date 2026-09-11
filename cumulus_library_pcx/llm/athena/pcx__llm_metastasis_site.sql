CREATE TABLE pcx__llm_metastasis_site AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_metastasis_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        metastasis_site_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        metastasis_site.site                                         AS site,
        metastasis_site.site_date                                    AS site_date,
        metastasis_site.site_date_precision                          AS site_date_precision
FROM
        pcx__nlp_metastasis_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.metastasis_sites) WITH ORDINALITY AS metastasis_site_t (metastasis_site, metastasis_site_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
