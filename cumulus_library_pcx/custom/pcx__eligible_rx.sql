--  =====================================================================
--  Eligibility: medications
--
--  Methotrexate is the causal contrast, the six backbone agents are chemo.
--  Structured evidence is MedicationRequest (an ORDER, not proof of receipt):
--    pcx__cohort_variable_union_rx for rx_contrast_methotrexate and rx_chemo_*
--  LLM evidence is pcx__llm_systemic_therapy_agent with
--  delivery_status = ADMINISTERED, which is receipt.
--  Every dated candidate is unioned with its source, then the earliest date per
--  exposure is taken, so adding a source is one more UNION branch.
--  "prior to t0" supports the ACNS0334 no-prior-chemotherapy criterion.
--  =====================================================================
CREATE  TABLE   pcx__eligible_rx AS
WITH
candidate AS (
    SELECT  subject_ref,
            'methotrexate'              AS exposure,
            'rx_order'                  AS source,
            rx_authoredon_date          AS exposure_day
    FROM    pcx__cohort_variable_union_rx
    WHERE   variable = 'rx_contrast_methotrexate'
    UNION ALL
    SELECT  subject_ref,
            'chemo'                     AS exposure,
            'rx_order'                  AS source,
            rx_authoredon_date          AS exposure_day
    FROM    pcx__cohort_variable_union_rx
    WHERE   variable LIKE 'rx_chemo_%'
    UNION ALL
    SELECT  subject_ref,
            'methotrexate'              AS exposure,
            'llm_administered'          AS source,
            CAST(therapy_start_date AS DATE) AS exposure_day
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   delivery_status = 'ADMINISTERED'
    AND     (LOWER(agent_name) LIKE '%methotrexate%' OR LOWER(agent_name) LIKE '%mtx%')
    UNION ALL
    SELECT  subject_ref,
            'chemo'                     AS exposure,
            'llm_administered'          AS source,
            CAST(therapy_start_date AS DATE) AS exposure_day
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   delivery_status = 'ADMINISTERED'
),
first_day AS (
    SELECT  subject_ref,
            MIN(CASE WHEN exposure = 'methotrexate'                         THEN exposure_day END) AS methotrexate_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'rx_order' THEN exposure_day END) AS methotrexate_order_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'llm_administered' THEN exposure_day END) AS methotrexate_administered_first_day,
            MIN(CASE WHEN exposure = 'chemo'                                THEN exposure_day END) AS chemo_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'rx_order'        THEN exposure_day END) AS chemo_order_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'llm_administered' THEN exposure_day END) AS chemo_administered_first_day,
            BOOL_OR(exposure = 'methotrexate')                              AS methotrexate_any_bool,
            BOOL_OR(exposure = 'methotrexate' AND source = 'llm_administered') AS methotrexate_administered_bool,
            BOOL_OR(exposure = 'chemo')                                     AS chemo_any_bool
    FROM    candidate
    GROUP BY subject_ref
)
SELECT  dx.subject_ref,
        dx.t0_day,
        first_day.methotrexate_first_day,
        first_day.methotrexate_order_first_day,
        first_day.methotrexate_administered_first_day,
        first_day.chemo_first_day,
        first_day.chemo_order_first_day,
        first_day.chemo_administered_first_day,
        first_day.methotrexate_any_bool,
        first_day.methotrexate_administered_bool,
        first_day.chemo_any_bool,
        (first_day.chemo_first_day < dx.t0_day)                             AS chemo_prior_to_t0_bool
FROM    pcx__eligible_dx   AS dx
LEFT JOIN first_day                 ON first_day.subject_ref = dx.subject_ref
;