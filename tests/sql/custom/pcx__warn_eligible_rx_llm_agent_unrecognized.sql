-- ============================================================================
-- Warning: an LLM "administered" agent that counts as chemo but is not one of
-- the study agents.
--
-- pcx__eligible_rx counts every pcx__llm_systemic_therapy_agent ADMINISTERED
-- at the agent level, or with an ADMINISTERED dose in the same extraction
-- output, as chemotherapy, except the supportive markers LEUCOVORIN, MESNA and
-- DEXRAZOXANE. A salvage or non-medulloblastoma
-- agent (temozolomide, bevacizumab, a BRAF or MEK inhibitor) or an unlisted
-- agent (NONE_OF_THE_ABOVE) therefore sets chemo_any_bool and can set
-- chemo_prior_to_t0_bool. This table lists each subject x agent x verbatim
-- spelling that is not one of the seven study agents (methotrexate,
-- carboplatin, cisplatin, cyclophosphamide, etoposide, thiotepa,
-- vincristine), so the agent vocabulary can be reviewed.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_rx_llm_agent_unrecognized AS

WITH administered_agent AS (
    SELECT  subject_ref,
            note_ref,
            agent_name,
            agent_name_verbatim,
            therapy_start_day                       AS exposure_day
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   delivery_status = 'ADMINISTERED'
    UNION ALL
    SELECT  agent.subject_ref,
            agent.note_ref,
            agent.agent_name,
            agent.agent_name_verbatim,
            dose.administration_day
    FROM    pcx__llm_systemic_therapy_administration    AS dose
    JOIN    pcx__llm_systemic_therapy_agent             AS agent
    ON      agent.note_ref      = dose.note_ref
    AND     agent.generated_on  = dose.generated_on
    AND     agent.regimen_index = dose.regimen_index
    AND     agent.agent_index   = dose.agent_index
    WHERE   dose.delivery_status = 'ADMINISTERED'
),
administered AS (
    SELECT  subject_ref,
            agent_name,
            LOWER(agent_name_verbatim)              AS verbatim,
            MIN(exposure_day)                       AS first_day,
            COUNT(DISTINCT note_ref)                AS note_cnt
    FROM    administered_agent
    WHERE   agent_name NOT IN (
                'METHOTREXATE', 'CARBOPLATIN', 'CISPLATIN', 'CYCLOPHOSPHAMIDE',
                'ETOPOSIDE', 'THIOTEPA', 'VINCRISTINE',
                'LEUCOVORIN', 'MESNA', 'DEXRAZOXANE')
    GROUP BY subject_ref, agent_name, LOWER(agent_name_verbatim)
)

SELECT  'rx_llm_agent_unrecognized'                                             AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('agent=',        agent_name),
            CONCAT('verbatim=',     verbatim),
            CONCAT('first=',        CAST(first_day AS VARCHAR)),
            CONCAT('notes=',        CAST(note_cnt AS VARCHAR)))                 AS detail
FROM    administered
;
