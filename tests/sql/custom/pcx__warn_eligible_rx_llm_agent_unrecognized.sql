-- ============================================================================
-- Warning: an LLM "administered" agent that counts as chemo but is not one of
-- the study agents.
--
-- pcx__eligible_rx counts every pcx__llm_systemic_therapy_agent row with
-- delivery_status = ADMINISTERED as chemotherapy, except the supportive
-- markers LEUCOVORIN, MESNA and DEXRAZOXANE. A salvage or non-medulloblastoma
-- agent (temozolomide, bevacizumab, a BRAF or MEK inhibitor) or an unlisted
-- agent (NONE_OF_THE_ABOVE) therefore sets chemo_any_bool and can set
-- chemo_prior_to_t0_bool. This table lists each subject x agent x verbatim
-- spelling that is not one of the seven study agents (methotrexate,
-- carboplatin, cisplatin, cyclophosphamide, etoposide, thiotepa,
-- vincristine), so the agent vocabulary can be reviewed.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_rx_llm_agent_unrecognized AS

WITH administered AS (
    SELECT  subject_ref,
            agent_name,
            LOWER(agent_name_verbatim)              AS verbatim,
            MIN(therapy_start_day)                  AS first_day,
            COUNT(DISTINCT note_ref)                AS note_cnt
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   delivery_status = 'ADMINISTERED'
    AND     agent_name NOT IN (
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
