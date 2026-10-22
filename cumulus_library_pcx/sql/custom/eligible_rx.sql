--  =====================================================================
--  Eligibility: medications
--
--  Methotrexate is the causal contrast. The CHOP clinical team treats any
--  methotrexate given to these patients as high-dose (2026-10-22), so it
--  counts from LLM evidence, two sources:
--    llm_administered        methotrexate ADMINISTERED at the agent level or
--                            at the dose level, any route
--    llm_acns0334_regimen_b  a regimen with protocol_name ACNS0334 and
--                            documented_trial_arm REGIMEN_B. The assignment
--                            alone counts, dated by regimen_start_day, and
--                            methotrexate ADMINISTERED within that regimen
--                            (agent or dose) adds its own dates
--  methotrexate_source lists which of the two gave evidence. Evidence that
--  does not change exposure, kept so it can be reported or split out:
--    methotrexate_high_dose_*            a dose the note calls high-dose
--    methotrexate_intrathecal_or_ventricular_*  a dose given intrathecally or
--                            intraventricularly (open question to CHOP: does
--                            it count)
--    methotrexate_not_received_bool      methotrexate EXPLICITLY_NOT_RECEIVED
--                            at the agent or dose level
--  Structured methotrexate (MedicationRequest orders, MedicationDispense
--  hand-overs, rx_contrast_methotrexate) has no dose or route, so it is
--  EVIDENCE ONLY: methotrexate_order_first_day / _dispense_first_day, never
--  methotrexate_first_day or methotrexate_any_bool.
--
--  Chemotherapy is the six backbone agents (structured orders and
--  dispenses), plus every LLM agent ADMINISTERED at the agent level or at
--  the dose level, earliest date wins, any methotrexate included, except
--  the supportive markers LEUCOVORIN, MESNA and DEXRAZOXANE
--  (NONE_OF_THE_ABOVE is an unlisted anticancer agent, so chemo).
--    rx_order     MedicationRequest authoredOn, an ORDER, not proof of receipt
--                 (pcx__cohort_variable_union_rx, built on core__medicationrequest)
--    rx_dispense  core__medicationdispense whenHandedOver, the pharmacy handed
--                 it over. Closer to receipt, still not administration. Epic
--                 dispensing is where infusion-center and inpatient doses appear.
--  Every candidate is unioned with its source, then the earliest date per
--  exposure is taken, so adding a source is one more UNION branch.
--  Orders are linked to study_population encounters, dispenses are matched for
--  every case subject.
--  Flags are yes/no, they never remove a subject:
--    *_any_bool          ever exposed, any date. FALSE = no evidence
--    *_prior_to_t0_bool  first dated exposure before t0_day. FALSE when t0 is
--                        known and nothing is dated before it (including no
--                        evidence at all), NULL only when t0_day is NULL
--    *_undated_bool      an exposure with no usable date exists, so its
--                        timing is unknown
--  *_first_day_from_t0 is the first exposure on or after t0_day, the start of
--  the initial-therapy window that pcx__outcome_exposure applies.
--  pcx__eligible_trial applies the prior-to-t0 flags as the ACNS0334
--  no-prior-chemotherapy criterion, methotrexate included.
--  =====================================================================
CREATE  TABLE   pcx__eligible_rx AS
WITH
rx_valueset AS (
    SELECT  'methotrexate_structured' AS exposure, "system", code FROM pcx__valueset_rx_contrast_methotrexate
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
-- every LLM administration, at the agent level and at the dose level
llm_administered AS (
    SELECT  subject_ref,
            note_ref,
            regimen_index,
            agent_name,
            therapy_start_day                       AS exposure_day,
            CAST(NULL AS BOOLEAN)                   AS high_dose_bool,
            CAST(NULL AS VARCHAR)                   AS route
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   delivery_status = 'ADMINISTERED'
    UNION ALL
    SELECT  dose.subject_ref,
            dose.note_ref,
            dose.regimen_index,
            agent.agent_name,
            dose.administration_day,
            dose.high_dose_methotrexate_explicit_bool,
            dose.route
    FROM    pcx__llm_systemic_therapy_administration    AS dose
    JOIN    pcx__llm_systemic_therapy_agent             AS agent
    ON      agent.note_ref      = dose.note_ref
    AND     agent.regimen_index = dose.regimen_index
    AND     agent.agent_index   = dose.agent_index
    WHERE   dose.delivery_status = 'ADMINISTERED'
),
regimen_b AS (
    SELECT  subject_ref,
            note_ref,
            regimen_index,
            regimen_start_day
    FROM    pcx__llm_systemic_therapy_regimen
    WHERE   protocol_name = 'ACNS0334'
    AND     documented_trial_arm = 'REGIMEN_B'
),
candidate AS (
    SELECT  subject_ref,
            'methotrexate_structured'   AS exposure,
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
            exposure_day
    FROM    llm_administered
    WHERE   agent_name = 'METHOTREXATE'
    UNION ALL
    SELECT  subject_ref,
            'methotrexate'              AS exposure,
            'llm_acns0334_regimen_b'    AS source,
            regimen_start_day           AS exposure_day
    FROM    regimen_b
    UNION ALL
    SELECT  administered.subject_ref,
            'methotrexate'              AS exposure,
            'llm_acns0334_regimen_b'    AS source,
            administered.exposure_day
    FROM    llm_administered    AS administered
    JOIN    regimen_b
    ON      regimen_b.note_ref      = administered.note_ref
    AND     regimen_b.regimen_index = administered.regimen_index
    WHERE   administered.agent_name = 'METHOTREXATE'
    UNION ALL
    SELECT  subject_ref,
            'chemo'                     AS exposure,
            'llm_administered'          AS source,
            exposure_day
    FROM    llm_administered
    WHERE   agent_name NOT IN ('LEUCOVORIN', 'MESNA', 'DEXRAZOXANE')
),
-- methotrexate evidence that does not change exposure
methotrexate_detail AS (
    SELECT  subject_ref,
            MIN(CASE WHEN high_dose_bool THEN exposure_day END)                             AS methotrexate_high_dose_first_day,
            BOOL_OR(high_dose_bool)                                                         AS methotrexate_high_dose_bool,
            MIN(CASE WHEN route IN ('INTRATHECAL', 'INTRAVENTRICULAR') THEN exposure_day END)
                                                                                            AS methotrexate_intrathecal_or_ventricular_first_day,
            BOOL_OR(route IN ('INTRATHECAL', 'INTRAVENTRICULAR'))                           AS methotrexate_intrathecal_or_ventricular_bool
    FROM    llm_administered
    WHERE   agent_name = 'METHOTREXATE'
    GROUP BY subject_ref
),
methotrexate_not_received AS (
    SELECT  subject_ref
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   agent_name = 'METHOTREXATE'
    AND     delivery_status = 'EXPLICITLY_NOT_RECEIVED'
    UNION
    SELECT  dose.subject_ref
    FROM    pcx__llm_systemic_therapy_administration    AS dose
    JOIN    pcx__llm_systemic_therapy_agent             AS agent
    ON      agent.note_ref      = dose.note_ref
    AND     agent.regimen_index = dose.regimen_index
    AND     agent.agent_index   = dose.agent_index
    WHERE   agent.agent_name = 'METHOTREXATE'
    AND     dose.delivery_status = 'EXPLICITLY_NOT_RECEIVED'
),
methotrexate_source AS (
    SELECT  subject_ref,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(DISTINCT source)), ',')                AS methotrexate_source
    FROM    candidate
    WHERE   exposure = 'methotrexate'
    GROUP BY subject_ref
),
first_day AS (
    SELECT  candidate.subject_ref,
            MIN(CASE WHEN exposure = 'methotrexate'                                     THEN exposure_day END) AS methotrexate_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND exposure_day >= dx.t0_day      THEN exposure_day END) AS methotrexate_first_day_from_t0,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'llm_administered'     THEN exposure_day END) AS methotrexate_administered_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'llm_acns0334_regimen_b' THEN exposure_day END) AS methotrexate_regimen_b_first_day,
            MIN(CASE WHEN exposure = 'methotrexate_structured' AND source = 'rx_order'  THEN exposure_day END) AS methotrexate_order_first_day,
            MIN(CASE WHEN exposure = 'methotrexate_structured' AND source = 'rx_dispense' THEN exposure_day END) AS methotrexate_dispense_first_day,
            MIN(CASE WHEN exposure = 'chemo'                                            THEN exposure_day END) AS chemo_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND exposure_day >= dx.t0_day             THEN exposure_day END) AS chemo_first_day_from_t0,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'rx_order'                    THEN exposure_day END) AS chemo_order_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'rx_dispense'                 THEN exposure_day END) AS chemo_dispense_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'llm_administered'            THEN exposure_day END) AS chemo_administered_first_day,
            BOOL_OR(exposure = 'methotrexate')                                          AS methotrexate_any_bool,
            BOOL_OR(exposure = 'methotrexate' AND source = 'llm_administered')          AS methotrexate_administered_bool,
            BOOL_OR(exposure = 'methotrexate' AND source = 'llm_acns0334_regimen_b')    AS methotrexate_regimen_b_bool,
            BOOL_OR(exposure = 'methotrexate' AND exposure_day IS NULL)                 AS methotrexate_undated_bool,
            BOOL_OR(exposure = 'chemo')                                                 AS chemo_any_bool,
            BOOL_OR(exposure = 'chemo' AND exposure_day IS NULL)                        AS chemo_undated_bool
    FROM    candidate
    JOIN    pcx__eligible_dx    AS dx ON dx.subject_ref = candidate.subject_ref
    GROUP BY candidate.subject_ref
)
SELECT  dx.subject_ref,
        dx.t0_day,
        first_day.methotrexate_first_day,
        first_day.methotrexate_first_day_from_t0,
        mtx_source.methotrexate_source,
        first_day.methotrexate_administered_first_day,
        first_day.methotrexate_regimen_b_first_day,
        mtx_detail.methotrexate_high_dose_first_day,
        mtx_detail.methotrexate_intrathecal_or_ventricular_first_day,
        first_day.methotrexate_order_first_day,
        first_day.methotrexate_dispense_first_day,
        first_day.chemo_first_day,
        first_day.chemo_first_day_from_t0,
        first_day.chemo_order_first_day,
        first_day.chemo_dispense_first_day,
        first_day.chemo_administered_first_day,
        COALESCE(first_day.methotrexate_any_bool, FALSE)                    AS methotrexate_any_bool,
        COALESCE(first_day.methotrexate_administered_bool, FALSE)           AS methotrexate_administered_bool,
        COALESCE(first_day.methotrexate_regimen_b_bool, FALSE)              AS methotrexate_regimen_b_bool,
        COALESCE(first_day.methotrexate_undated_bool, FALSE)                AS methotrexate_undated_bool,
        COALESCE(mtx_detail.methotrexate_high_dose_bool, FALSE)             AS methotrexate_high_dose_bool,
        COALESCE(mtx_detail.methotrexate_intrathecal_or_ventricular_bool, FALSE)
                                                                            AS methotrexate_intrathecal_or_ventricular_bool,
        (mtx_not_received.subject_ref IS NOT NULL)                          AS methotrexate_not_received_bool,
        COALESCE(first_day.chemo_any_bool, FALSE)                           AS chemo_any_bool,
        COALESCE(first_day.chemo_undated_bool, FALSE)                       AS chemo_undated_bool,
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
LEFT JOIN first_day                 ON first_day.subject_ref  = dx.subject_ref
LEFT JOIN methotrexate_source AS mtx_source ON mtx_source.subject_ref = dx.subject_ref
LEFT JOIN methotrexate_detail AS mtx_detail ON mtx_detail.subject_ref = dx.subject_ref
LEFT JOIN methotrexate_not_received AS mtx_not_received ON mtx_not_received.subject_ref = dx.subject_ref
;
