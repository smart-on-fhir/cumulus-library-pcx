CREATE TABLE pcx__llm_radiation_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_radiation_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        radiation_round_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        radiation_round.delivery_status                              AS delivery_status,
        radiation_round.phase                                        AS phase,
        radiation_round.indication                                   AS indication,
        radiation_round.assessed_through_date                        AS assessed_through_date,
        radiation_round.assessed_through_date_precision              AS assessed_through_date_precision,
        radiation_round.dose_verbatim                                AS dose_verbatim,
        radiation_round.radiation_method                             AS radiation_method,
        radiation_round.radiation_field                              AS radiation_field,
        radiation_round.radiation_start_date                         AS radiation_start_date,
        radiation_round.radiation_start_date_precision               AS radiation_start_date_precision,
        radiation_round.radiation_end_date                           AS radiation_end_date,
        radiation_round.radiation_end_date_precision                 AS radiation_end_date_precision,
        radiation_round.focal_dose_to_primary_site                   AS focal_dose_to_primary_site,
        radiation_round.total_dose_to_primary_site                   AS total_dose_to_primary_site,
        radiation_round.focal_dose_to_metastatic_site                AS focal_dose_to_metastatic_site,
        radiation_round.total_dose_to_metastatic_site                AS total_dose_to_metastatic_site,
        radiation_round.craniospinal_dose                            AS craniospinal_dose,
        radiation_round.whole_ventricular_dose                       AS whole_ventricular_dose,
        radiation_round.dose_units                                   AS dose_units
FROM
        pcx__nlp_radiation_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.radiation_rounds) WITH ORDINALITY AS radiation_round_t (radiation_round, radiation_round_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
