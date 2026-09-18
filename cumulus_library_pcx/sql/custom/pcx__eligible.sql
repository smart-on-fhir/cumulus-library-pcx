--  =====================================================================
--  Eligibility: one row per case-definition subject with every ACNS0334
--  criterion as its own nullable column. NULL means not evaluable from the
--  evidence on hand, never "met" and never "not met".
--
--  This is the DISCOVERY cohort (all ages). pcx__eligible_trial applies
--  the strict trial-like intersection on top of it.
--  =====================================================================
CREATE  TABLE   pcx__eligible AS
SELECT  dx.subject_ref,
        dx.gender,
        dx.birthdate,
        -- time zero and age
        dx.t0_day,
        dx.t0_source,
        dx.age_months_at_t0,
        CASE
            WHEN dx.age_months_at_t0 IS NULL   THEN NULL
            WHEN dx.age_months_at_t0 < 36      THEN 'under_36_months'
            ELSE                                    '36_months_or_older'
        END                                                             AS age_band_at_t0,
        surgery.definitive_surgery_day,
        surgery.definitive_surgery_source,
        surgery.age_months_at_definitive_surgery,
        -- ACNS0334 criteria, structurally evaluable
        dx.medulloblastoma_tier1_bool,
        dx.llm_medulloblastoma_bool,
        surgery.age_under_36_months_at_definitive_surgery,
        CASE
            WHEN dx.atrt_tier1_bool                                     THEN TRUE
            WHEN dx.llm_atrt_bool                                       THEN TRUE
            ELSE FALSE
        END                                                             AS atrt_confirmed_bool,
        CASE
            WHEN rx.chemo_prior_to_t0_bool                              THEN FALSE
            WHEN rx.chemo_any_bool                                      THEN TRUE
            ELSE NULL
        END                                                             AS no_prior_chemotherapy_bool,
        CASE
            WHEN radiation.radiation_prior_to_t0_bool                   THEN FALSE
            WHEN radiation.radiation_any_bool                           THEN TRUE
            WHEN radiation.llm_explicitly_not_received_bool             THEN TRUE
            ELSE NULL
        END                                                             AS no_prior_radiation_bool,
        -- high-risk stratum inputs (adjudicate downstream)
        dx.llm_metastatic_bool,
        dx.llm_anaplastic_bool,
        surgery.llm_residual_disease_bool,
        surgery.llm_residual_tumor_area_cm2_max,
        (dx.age_months_at_t0 < 8)                                       AS age_under_8_months_at_t0,
        -- exposures (any time, see outcome stage for timing relative to first event)
        rx.methotrexate_any_bool,
        rx.methotrexate_first_day,
        rx.chemo_any_bool,
        rx.chemo_first_day,
        radiation.radiation_any_bool,
        radiation.radiation_first_day,
        radiation.llm_craniospinal_bool,
        radiation.llm_proton_bool
FROM    pcx__eligible_dx           AS dx
LEFT JOIN pcx__eligible_surgery    AS surgery   ON surgery.subject_ref   = dx.subject_ref
LEFT JOIN pcx__eligible_rx         AS rx        ON rx.subject_ref        = dx.subject_ref
LEFT JOIN pcx__eligible_radiation  AS radiation ON radiation.subject_ref = dx.subject_ref
;