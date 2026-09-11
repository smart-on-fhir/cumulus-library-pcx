CREATE TABLE pcx__llm_medulloblastoma_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_medulloblastoma_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- mention values only: spans and has_mention stay in the source nlp table
        nlp.result.molecular_group.classification_method             AS molecular_group_classification_method,
        nlp.result.molecular_group.source_report                     AS molecular_group_source_report,
        nlp.result.molecular_group."group"                           AS molecular_group,
        nlp.result.methotrexate.status                               AS methotrexate_status,
        nlp.result.methotrexate.first_received_date                  AS methotrexate_first_received_date,
        nlp.result.methotrexate.assessed_through_date                AS methotrexate_assessed_through_date,
        nlp.result.radiation.status                                  AS radiation_status,
        nlp.result.radiation.first_received_date                     AS radiation_first_received_date,
        nlp.result.radiation.assessed_through_date                   AS radiation_assessed_through_date,
        nlp.result.survival.patient_deceased                         AS patient_deceased,
        nlp.result.survival.death_date                               AS death_date,
        nlp.result.survival.last_known_alive_date                    AS last_known_alive_date
FROM
        pcx__nlp_medulloblastoma_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
