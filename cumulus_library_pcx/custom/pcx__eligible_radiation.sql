--  =====================================================================
--  Eligibility: radiation
--
--  Structured evidence (candidate valuesets, verify before trusting):
--    pcx__cohort_proc_radiation tier 1 = delivery or management procedure
--    pcx__cohort_dx_radiation   tier 1 = radiotherapy encounter code
--  LLM evidence is pcx__llm_radiation_wide with delivery_status = ADMINISTERED.
--  Same candidate-union shape as eligible_rx.
--  "prior to t0" supports the ACNS0334 no-prior-radiation criterion.
--  =====================================================================
CREATE  TABLE   pcx__eligible_radiation AS
WITH
candidate AS (
    SELECT  subject_ref,
            'proc_radiation'            AS source,
            proc_performed_day          AS exposure_day
    FROM    pcx__cohort_proc_radiation
    WHERE   tier = 1
    UNION ALL
    SELECT  subject_ref,
            'dx_radiation'              AS source,
            dx_recorded_date            AS exposure_day
    FROM    pcx__cohort_dx_radiation
    WHERE   tier = 1
    UNION ALL
    SELECT  subject_ref,
            'llm_administered'          AS source,
            CAST(radiation_start_date AS DATE) AS exposure_day
    FROM    pcx__llm_radiation_wide
    WHERE   delivery_status = 'ADMINISTERED'
),
first_day AS (
    SELECT  subject_ref,
            MIN(exposure_day)                                                   AS radiation_first_day,
            MIN(CASE WHEN source = 'proc_radiation'   THEN exposure_day END)    AS radiation_proc_first_day,
            MIN(CASE WHEN source = 'dx_radiation'     THEN exposure_day END)    AS radiation_dx_first_day,
            MIN(CASE WHEN source = 'llm_administered' THEN exposure_day END)    AS radiation_administered_first_day,
            (COUNT(*) > 0)                                                      AS radiation_any_bool,
            BOOL_OR(source = 'llm_administered')                                AS radiation_administered_bool
    FROM    candidate
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
        first_day.radiation_any_bool,
        first_day.radiation_administered_bool,
        llm_field.llm_craniospinal_bool,
        llm_field.llm_proton_bool,
        llm_field.llm_explicitly_not_received_bool,
        (first_day.radiation_first_day < dx.t0_day)                         AS radiation_prior_to_t0_bool
FROM    pcx__eligible_dx   AS dx
LEFT JOIN first_day                 ON first_day.subject_ref = dx.subject_ref
LEFT JOIN llm_field                 ON llm_field.subject_ref = dx.subject_ref
;