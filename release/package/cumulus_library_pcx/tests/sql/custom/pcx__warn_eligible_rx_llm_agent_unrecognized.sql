-- ============================================================================
-- Warning: an LLM "administered" agent that is not one of the study agents.
--
-- pcx__eligible_rx counts EVERY pcx__llm_systemic_therapy_agent row with
-- delivery_status = ADMINISTERED as chemotherapy, whatever the agent. A
-- regimen that lists leucovorin, filgrastim, ondansetron or a steroid as an
-- agent therefore sets chemo_any_bool and can set chemo_prior_to_t0_bool.
-- This table lists each subject x agent name that does not match the seven
-- study agents (methotrexate, carboplatin, cisplatin, cyclophosphamide,
-- etoposide, thiotepa, vincristine) so the agent vocabulary can be reviewed.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_rx_llm_agent_unrecognized AS

WITH administered AS (
    SELECT  subject_ref,
            LOWER(agent_name)                       AS agent_lower,
            MIN(CAST(therapy_start_date AS DATE))   AS first_day,
            COUNT(DISTINCT note_ref)                AS note_cnt
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   delivery_status = 'ADMINISTERED'
    AND     agent_name IS NOT NULL
    GROUP BY subject_ref, LOWER(agent_name)
)

SELECT  'rx_llm_agent_unrecognized'                                             AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('agent=',        agent_lower),
            CONCAT('first=',        CAST(first_day AS VARCHAR)),
            CONCAT('notes=',        CAST(note_cnt AS VARCHAR)))                 AS detail
FROM    administered
WHERE   NOT (
            agent_lower LIKE '%methotrexate%'
        OR  agent_lower LIKE '%mtx%'
        OR  agent_lower LIKE '%carboplatin%'
        OR  agent_lower LIKE '%cisplatin%'
        OR  agent_lower LIKE '%cyclophosphamide%'
        OR  agent_lower LIKE '%cytoxan%'
        OR  agent_lower LIKE '%etoposide%'
        OR  agent_lower LIKE '%vp-16%'
        OR  agent_lower LIKE '%vp16%'
        OR  agent_lower LIKE '%thiotepa%'
        OR  agent_lower LIKE '%vincristine%'
        )
;
