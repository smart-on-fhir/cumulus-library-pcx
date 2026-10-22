--  =====================================================================
--  Eligibility: radiation
--
--  Evidence comes from pcx__exposure_record (exposure = radiation):
--    proc_radiation    pcx__cohort_proc_radiation tier 1, a delivery or
--                      management procedure (candidate valueset, verify)
--    dx_radiation      pcx__cohort_dx_radiation tier 1, a radiotherapy
--                      encounter code (candidate valueset, verify)
--    llm_administered  pcx__llm_radiation_wide with delivery_status ADMINISTERED
--  Same flags as eligible_rx:
--    radiation_any_bool          ever radiated, FALSE = no evidence
--    radiation_undated_bool      radiation evidence with no usable date
--    radiation_prior_to_t0_bool  TRUE when a dated record ends before t0_day,
--                                NULL when t0_day is NULL or a month or year
--                                date straddles it and none ends before it,
--                                FALSE otherwise (undated evidence never counts)
--  pcx__eligible_trial applies radiation_prior_to_t0_bool as the ACNS0334
--  no-prior-radiation criterion.
--  =====================================================================
CREATE  TABLE   pcx__eligible_radiation AS
WITH
record AS (
    SELECT  record.*,
            dx.t0_day
    FROM    pcx__exposure_record    AS record
    JOIN    pcx__eligible_dx        AS dx ON dx.subject_ref = record.subject_ref
    WHERE   record.exposure = 'radiation'
),
first_day AS (
    SELECT  subject_ref,
            MIN(exposure_day)                                                   AS radiation_first_day,
            MIN(CASE WHEN source = 'proc_radiation'   THEN exposure_day END)    AS radiation_proc_first_day,
            MIN(CASE WHEN source = 'dx_radiation'     THEN exposure_day END)    AS radiation_dx_first_day,
            MIN(CASE WHEN source = 'llm_administered' THEN exposure_day END)    AS radiation_administered_first_day,
            BOOL_OR(source = 'llm_administered')                                AS radiation_administered_bool,
            BOOL_OR(exposure_day IS NULL)                                       AS radiation_undated_bool,
            BOOL_OR(latest_day < t0_day AND exposure_day IS NOT NULL)           AS radiation_before_t0_bool,
            BOOL_OR(exposure_day < t0_day)                                      AS radiation_may_precede_t0_bool
    FROM    record
    GROUP BY subject_ref
),
llm_field AS (
    SELECT  subject_ref,
            BOOL_OR(radiation_field IN ('CRANIOSPINAL', 'CRANIOSPINAL_WITH_FOCAL_BOOST'))  AS llm_craniospinal_bool,
            BOOL_OR(radiation_method = 'PROTON')                                        AS llm_proton_bool,
            BOOL_OR(delivery_status = 'EXPLICITLY_NOT_RECEIVED')                        AS llm_explicitly_not_received_bool
    FROM    pcx__llm_radiation_wide
    GROUP BY subject_ref
)
SELECT  dx.subject_ref,
        dx.t0_day,
        first_day.radiation_first_day,
        first_day.radiation_proc_first_day,
        first_day.radiation_dx_first_day,
        first_day.radiation_administered_first_day,
        (first_day.subject_ref IS NOT NULL)                                 AS radiation_any_bool,
        first_day.radiation_administered_bool,
        COALESCE(first_day.radiation_undated_bool, FALSE)                   AS radiation_undated_bool,
        llm_field.llm_craniospinal_bool,
        llm_field.llm_proton_bool,
        llm_field.llm_explicitly_not_received_bool,
        CASE
            WHEN dx.t0_day IS NULL                                          THEN NULL
            WHEN first_day.radiation_before_t0_bool                         THEN TRUE
            WHEN first_day.radiation_may_precede_t0_bool                    THEN NULL
            ELSE                                                                 FALSE
        END                                                                 AS radiation_prior_to_t0_bool
FROM    pcx__eligible_dx   AS dx
LEFT JOIN first_day                 ON first_day.subject_ref = dx.subject_ref
LEFT JOIN llm_field                 ON llm_field.subject_ref = dx.subject_ref
;
