--  =====================================================================
--  Eligibility: one row per case-definition subject with every ACNS0334
--  criterion as its own column. NULL means not evaluable from the
--  evidence on hand, never "met" and never "not met".
--
--  This is the DISCOVERY cohort (all ages). Age, prior methotrexate, prior
--  chemotherapy and prior radiation are yes/no FLAGS here, not exclusions:
--  a subject diagnosed at 36 months or older, or exposed to methotrexate or
--  radiation before t0, is still in {{ prefix }}__eligible.
--    age_under_36_months_at_t0 / _at_definitive_surgery   NULL without a day or birthdate
--    *_prior_to_t0_bool   TRUE = dated exposure before t0_day, NULL without t0
--    *_any_bool           TRUE = exposure at any time, FALSE = no evidence
--  {{ prefix }}__eligible_trial applies the strict trial-like intersection on top of it.
--  =====================================================================
CREATE  TABLE   {{ prefix }}__eligible AS
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
        CASE
            WHEN dx.atrt_tier1_bool                                     THEN TRUE
            WHEN dx.llm_atrt_bool                                       THEN TRUE
            ELSE FALSE
        END                                                             AS atrt_confirmed_bool,
        -- relaxed criteria: flags only, {{ prefix }}__eligible_trial excludes on them
        dx.age_under_36_months_at_t0,
        surgery.age_under_36_months_at_definitive_surgery,
        rx.methotrexate_prior_to_t0_bool,
        rx.chemo_prior_to_t0_bool,
        radiation.radiation_prior_to_t0_bool,
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
FROM    {{ prefix }}__eligible_dx           AS dx
LEFT JOIN {{ prefix }}__eligible_surgery    AS surgery   ON surgery.subject_ref   = dx.subject_ref
LEFT JOIN {{ prefix }}__eligible_rx         AS rx        ON rx.subject_ref        = dx.subject_ref
LEFT JOIN {{ prefix }}__eligible_radiation  AS radiation ON radiation.subject_ref = dx.subject_ref
;