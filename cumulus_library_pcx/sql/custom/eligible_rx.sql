--  =====================================================================
--  Eligibility: medications
--
--  Methotrexate is the causal contrast, the six backbone agents are chemo.
--  Structured evidence is cumulus core, matched to the rx_* valuesets:
--    rx_order     MedicationRequest authoredOn, an ORDER, not proof of receipt
--                 (pcx__cohort_variable_union_rx, built on core__medicationrequest)
--    rx_dispense  core__medicationdispense whenHandedOver, the pharmacy handed
--                 it over. Closer to receipt, still not administration. Epic
--                 dispensing is where infusion-center and inpatient doses appear.
--  LLM evidence is pcx__llm_systemic_therapy_agent with
--  delivery_status = ADMINISTERED, which is receipt.
--  Every dated candidate is unioned with its source, then the earliest date per
--  exposure is taken, so adding a source is one more UNION branch.
--  Orders are linked to study_population encounters, dispenses are matched for
--  every case subject.
--  Flags are yes/no, they never remove a subject:
--    *_any_bool          ever exposed, any source, any date. FALSE = no evidence
--    *_prior_to_t0_bool  first dated exposure before t0_day. FALSE when t0 is
--                        known and nothing is dated before it (including no
--                        evidence at all), NULL only when t0_day is NULL
--  pcx__eligible_trial applies the prior-to-t0 flags as the ACNS0334
--  no-prior-chemotherapy criterion, methotrexate included.
--  =====================================================================
CREATE  TABLE   pcx__eligible_rx AS
WITH
rx_valueset AS (
    SELECT  'methotrexate' AS exposure, "system", code FROM pcx__valueset_rx_contrast_methotrexate
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_carboplatin
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_cisplatin
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_cyclophosphamide
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_etoposide
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_thiotepa
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_vincristine
),
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
    -- core__medicationdispense already drops entered-in-error
    SELECT  md.subject_ref,
            rx_valueset.exposure,
            'rx_dispense'               AS source,
            md.whenhandedover_day       AS exposure_day
    FROM    core__medicationdispense    AS md
    JOIN    rx_valueset
    ON      rx_valueset."system" = md.medication_system
    AND     rx_valueset.code = md.medication_code
    WHERE   md.whenhandedover_day IS NOT NULL
    AND     md.status NOT IN ('cancelled', 'declined')
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
            MIN(CASE WHEN exposure = 'methotrexate'                                 THEN exposure_day END) AS methotrexate_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'rx_order'         THEN exposure_day END) AS methotrexate_order_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'rx_dispense'      THEN exposure_day END) AS methotrexate_dispense_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'llm_administered' THEN exposure_day END) AS methotrexate_administered_first_day,
            MIN(CASE WHEN exposure = 'chemo'                                        THEN exposure_day END) AS chemo_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'rx_order'                THEN exposure_day END) AS chemo_order_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'rx_dispense'             THEN exposure_day END) AS chemo_dispense_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'llm_administered'        THEN exposure_day END) AS chemo_administered_first_day,
            BOOL_OR(exposure = 'methotrexate')                                      AS methotrexate_any_bool,
            BOOL_OR(exposure = 'methotrexate' AND source = 'llm_administered')      AS methotrexate_administered_bool,
            BOOL_OR(exposure = 'chemo')                                             AS chemo_any_bool
    FROM    candidate
    GROUP BY subject_ref
)
SELECT  dx.subject_ref,
        dx.t0_day,
        first_day.methotrexate_first_day,
        first_day.methotrexate_order_first_day,
        first_day.methotrexate_dispense_first_day,
        first_day.methotrexate_administered_first_day,
        first_day.chemo_first_day,
        first_day.chemo_order_first_day,
        first_day.chemo_dispense_first_day,
        first_day.chemo_administered_first_day,
        COALESCE(first_day.methotrexate_any_bool, FALSE)                    AS methotrexate_any_bool,
        first_day.methotrexate_administered_bool,
        COALESCE(first_day.chemo_any_bool, FALSE)                           AS chemo_any_bool,
        CASE
            WHEN dx.t0_day IS NULL                                          THEN NULL
            WHEN first_day.methotrexate_first_day < dx.t0_day               THEN TRUE
            ELSE                                                                 FALSE
        END                                                                 AS methotrexate_prior_to_t0_bool,
        CASE
            WHEN dx.t0_day IS NULL                                          THEN NULL
            WHEN first_day.chemo_first_day < dx.t0_day                      THEN TRUE
            ELSE                                                                 FALSE
        END                                                                 AS chemo_prior_to_t0_bool
FROM    pcx__eligible_dx   AS dx
LEFT JOIN first_day                 ON first_day.subject_ref = dx.subject_ref
;
