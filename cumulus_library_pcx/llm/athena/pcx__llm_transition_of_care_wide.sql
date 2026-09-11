CREATE TABLE pcx__llm_transition_of_care_wide AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_transition_of_care_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- mention values only: spans and has_mention stay in the source nlp table
        nlp.result.transfer_in.transfer_in_timing                                   AS transfer_in_timing,
        nlp.result.transfer_in.transfer_in_date                                     AS transfer_in_date,
        nlp.result.transfer_in.transfer_in_date_precision                           AS transfer_in_date_precision,
        nlp.result.transfer_in.transfer_in_reason                                   AS transfer_in_reason,
        nlp.result.diagnosis_setting.diagnosis_setting                              AS diagnosis_setting,
        nlp.result.diagnosis_setting.imaging_detected_externally                    AS imaging_detected_externally,
        nlp.result.definitive_surgery_setting.surgery_setting                       AS surgery_setting,
        nlp.result.prior_therapy_at_entry.prior_therapy_exposure                    AS prior_therapy_exposure,
        array_join(nlp.result.prior_therapy_at_entry.prior_therapy_modalities, ',') AS prior_therapy_modalities
FROM
        pcx__nlp_transition_of_care_gpt_oss_120b AS nlp
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
