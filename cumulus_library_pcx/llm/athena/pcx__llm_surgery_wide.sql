CREATE TABLE pcx__llm_surgery_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_surgery_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        surgery_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        surgery.surgery_role                                         AS surgery_role,
        surgery.age_at_surgery_months                                AS age_at_surgery_months,
        surgery.residual_tumor_area_cm2                              AS residual_tumor_area_cm2,
        surgery.residual_measurement_verbatim                        AS residual_measurement_verbatim,
        surgery.residual_assessment_date                             AS residual_assessment_date,
        surgery.residual_assessment_date_precision                   AS residual_assessment_date_precision,
        surgery.surgery_type                                         AS surgery_type,
        surgery.extent_of_resection                                  AS extent_of_resection,
        surgery.surgery_date                                         AS surgery_date,
        surgery.surgery_date_precision                               AS surgery_date_precision
FROM
        pcx__nlp_surgery_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.surgeries) WITH ORDINALITY AS surgery_t (surgery, surgery_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
