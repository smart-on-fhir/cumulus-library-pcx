CREATE TABLE pcx__llm_systemic_therapy_administration AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_systemic_therapy_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        regimen_index,
        agent_index,
        administration_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        administration.delivery_status                               AS delivery_status,
        administration.phase                                         AS phase,
        administration.cycle_name                                    AS cycle_name,
        administration.administration_date                           AS administration_date,
        administration.administration_date_precision                 AS administration_date_precision,
        administration.dose_amount                                   AS dose_amount,
        administration.dose_unit                                     AS dose_unit,
        administration.route                                         AS route,
        administration.high_dose_methotrexate_explicit_bool          AS high_dose_methotrexate_explicit_bool
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.regimens) WITH ORDINALITY AS regimen_t (regimen, regimen_index)
CROSS JOIN UNNEST(regimen.agents) WITH ORDINALITY AS agent_t (agent, agent_index)
CROSS JOIN UNNEST(agent.administrations) WITH ORDINALITY AS administration_t (administration, administration_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
