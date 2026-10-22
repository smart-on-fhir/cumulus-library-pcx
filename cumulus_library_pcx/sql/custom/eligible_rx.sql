--  =====================================================================
--  Eligibility: medications
--
--  Evidence comes from pcx__exposure_record, one row per record with its
--  source and the range of days it can fall on.
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
--  the dose level, any methotrexate included, except the supportive markers
--  LEUCOVORIN, MESNA and DEXRAZOXANE (NONE_OF_THE_ABOVE is an unlisted
--  anticancer agent, so chemo).
--    rx_order     MedicationRequest authoredOn, an ORDER, not proof of receipt
--                 (pcx__cohort_variable_union_rx, built on core__medicationrequest)
--    rx_dispense  core__medicationdispense whenHandedOver, the pharmacy handed
--                 it over. Closer to receipt, still not administration. Epic
--                 dispensing is where infusion-center and inpatient doses appear.
--  Orders are linked to study_population encounters, dispenses are matched for
--  every case subject.
--  Flags are yes/no, they never remove a subject:
--    *_any_bool          ever exposed, any date. FALSE = no evidence
--    *_undated_bool      an exposure with no usable date exists
--    *_prior_to_t0_bool  dated exposure before t0_day, by the range of days a
--                        record can fall on (a month or year date covers the
--                        whole period):
--                          TRUE   a record ends before t0_day
--                          NULL   t0_day is NULL, or no record ends before it
--                                 but one straddles it (a month or year date
--                                 that includes t0_day)
--                          FALSE  otherwise, including no evidence at all.
--                                 Undated evidence never counts here.
--  *_first_day is the earliest recorded day, the first day of its month or
--  year for a coarse date.
--  pcx__eligible_trial applies the prior-to-t0 flags as the ACNS0334
--  no-prior-chemotherapy criterion, methotrexate included.
--  =====================================================================
CREATE  TABLE   pcx__eligible_rx AS
WITH
record AS (
    SELECT  record.*,
            dx.t0_day
    FROM    pcx__exposure_record    AS record
    JOIN    pcx__eligible_dx        AS dx ON dx.subject_ref = record.subject_ref
    WHERE   record.exposure IN ('methotrexate', 'methotrexate_structured', 'chemo')
),
-- methotrexate evidence that does not change exposure
methotrexate_detail AS (
    SELECT  subject_ref,
            MIN(CASE WHEN high_dose_bool THEN exposure_day END)                             AS methotrexate_high_dose_first_day,
            BOOL_OR(high_dose_bool)                                                         AS methotrexate_high_dose_bool,
            MIN(CASE WHEN route IN ('INTRATHECAL', 'INTRAVENTRICULAR') THEN exposure_day END)
                                                                                            AS methotrexate_intrathecal_or_ventricular_first_day,
            BOOL_OR(route IN ('INTRATHECAL', 'INTRAVENTRICULAR'))                           AS methotrexate_intrathecal_or_ventricular_bool
    FROM    record
    WHERE   exposure = 'methotrexate'
    AND     source = 'llm_administered'
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
    AND     agent.generated_on  = dose.generated_on
    AND     agent.regimen_index = dose.regimen_index
    AND     agent.agent_index   = dose.agent_index
    WHERE   agent.agent_name = 'METHOTREXATE'
    AND     dose.delivery_status = 'EXPLICITLY_NOT_RECEIVED'
),
methotrexate_source AS (
    SELECT  subject_ref,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(DISTINCT source)), ',')                AS methotrexate_source
    FROM    record
    WHERE   exposure = 'methotrexate'
    GROUP BY subject_ref
),
first_day AS (
    SELECT  subject_ref,
            MIN(CASE WHEN exposure = 'methotrexate'                                     THEN exposure_day END) AS methotrexate_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'llm_administered'     THEN exposure_day END) AS methotrexate_administered_first_day,
            MIN(CASE WHEN exposure = 'methotrexate' AND source = 'llm_acns0334_regimen_b' THEN exposure_day END) AS methotrexate_regimen_b_first_day,
            MIN(CASE WHEN exposure = 'methotrexate_structured' AND source = 'rx_order'  THEN exposure_day END) AS methotrexate_order_first_day,
            MIN(CASE WHEN exposure = 'methotrexate_structured' AND source = 'rx_dispense' THEN exposure_day END) AS methotrexate_dispense_first_day,
            MIN(CASE WHEN exposure = 'chemo'                                            THEN exposure_day END) AS chemo_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'rx_order'                    THEN exposure_day END) AS chemo_order_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'rx_dispense'                 THEN exposure_day END) AS chemo_dispense_first_day,
            MIN(CASE WHEN exposure = 'chemo' AND source = 'llm_administered'            THEN exposure_day END) AS chemo_administered_first_day,
            BOOL_OR(exposure = 'methotrexate')                                          AS methotrexate_any_bool,
            BOOL_OR(exposure = 'methotrexate' AND source = 'llm_administered')          AS methotrexate_administered_bool,
            BOOL_OR(exposure = 'methotrexate' AND source = 'llm_acns0334_regimen_b')    AS methotrexate_regimen_b_bool,
            BOOL_OR(exposure = 'methotrexate' AND exposure_day IS NULL)                 AS methotrexate_undated_bool,
            BOOL_OR(exposure = 'chemo')                                                 AS chemo_any_bool,
            BOOL_OR(exposure = 'chemo' AND source = 'llm_administered')                 AS chemo_administered_bool,
            BOOL_OR(exposure = 'chemo' AND exposure_day IS NULL)                        AS chemo_undated_bool,
            -- prior to t0 by range: ends before t0, or straddles it
            BOOL_OR(exposure = 'methotrexate' AND latest_day < t0_day AND exposure_day IS NOT NULL)  AS methotrexate_before_t0_bool,
            BOOL_OR(exposure = 'methotrexate' AND exposure_day < t0_day)                AS methotrexate_may_precede_t0_bool,
            BOOL_OR(exposure = 'chemo' AND latest_day < t0_day AND exposure_day IS NOT NULL)         AS chemo_before_t0_bool,
            BOOL_OR(exposure = 'chemo' AND exposure_day < t0_day)                       AS chemo_may_precede_t0_bool
    FROM    record
    GROUP BY subject_ref
)
SELECT  dx.subject_ref,
        dx.t0_day,
        first_day.methotrexate_first_day,
        mtx_source.methotrexate_source,
        first_day.methotrexate_administered_first_day,
        first_day.methotrexate_regimen_b_first_day,
        mtx_detail.methotrexate_high_dose_first_day,
        mtx_detail.methotrexate_intrathecal_or_ventricular_first_day,
        first_day.methotrexate_order_first_day,
        first_day.methotrexate_dispense_first_day,
        first_day.chemo_first_day,
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
        COALESCE(first_day.chemo_administered_bool, FALSE)                  AS chemo_administered_bool,
        COALESCE(first_day.chemo_undated_bool, FALSE)                       AS chemo_undated_bool,
        CASE
            WHEN dx.t0_day IS NULL                                          THEN NULL
            WHEN first_day.methotrexate_before_t0_bool                      THEN TRUE
            WHEN first_day.methotrexate_may_precede_t0_bool                 THEN NULL
            ELSE                                                                 FALSE
        END                                                                 AS methotrexate_prior_to_t0_bool,
        CASE
            WHEN dx.t0_day IS NULL                                          THEN NULL
            WHEN first_day.chemo_before_t0_bool                             THEN TRUE
            WHEN first_day.chemo_may_precede_t0_bool                        THEN NULL
            ELSE                                                                 FALSE
        END                                                                 AS chemo_prior_to_t0_bool
FROM    pcx__eligible_dx   AS dx
LEFT JOIN first_day                 ON first_day.subject_ref  = dx.subject_ref
LEFT JOIN methotrexate_source AS mtx_source ON mtx_source.subject_ref = dx.subject_ref
LEFT JOIN methotrexate_detail AS mtx_detail ON mtx_detail.subject_ref = dx.subject_ref
LEFT JOIN methotrexate_not_received AS mtx_not_received ON mtx_not_received.subject_ref = dx.subject_ref
;
