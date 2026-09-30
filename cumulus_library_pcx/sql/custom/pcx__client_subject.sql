-- ==========================================================================
-- Grain: one row per subject_ref.
--
-- The client contract is the all-ages discovery cohort (every case-definition
-- subject in pcx__eligible). The ACNS0334 criteria ride along as columns so
-- the trial-like subset is a filter downstream, never a different table.
-- Survival and exposure summaries come from pcx__outcome, never re-derived.
-- ==========================================================================
CREATE TABLE pcx__client_subject AS
WITH
-- Observability window per subject, across all study-window encounters.
followup AS (
    SELECT  subject_ref,
            MIN(period_start_day)                       AS observation_start_date,
            MAX(period_end_day)                         AS observation_end_date
    FROM    pcx__cohort_study_period
    GROUP BY subject_ref
),

-- Most recently documented non-empty demographics per subject. Demographic
-- fields can be sparse or repeated across encounters, so resolve each field
-- independently rather than requiring all of them on the same row.
demographics AS (
    SELECT  sp.subject_ref,
            MAX_BY(sp.race_display,
                   ROW(sp.enc_period_start_day, sp.encounter_ref))
                FILTER (WHERE NULLIF(TRIM(sp.race_display), '') IS NOT NULL)
                                                        AS race_display,
            MAX_BY(sp.ethnicity_display,
                   ROW(sp.enc_period_start_day, sp.encounter_ref))
                FILTER (WHERE NULLIF(TRIM(sp.ethnicity_display), '') IS NOT NULL)
                                                        AS ethnicity_display,
            COUNT(DISTINCT sp.encounter_ref)            AS encounter_count
    FROM    pcx__cohort_study_population AS sp
    GROUP BY sp.subject_ref
),

trial AS (
    SELECT  DISTINCT subject_ref
    FROM    pcx__eligible_trial
)

SELECT  elig.subject_ref,
        elig.gender,
        demographics.race_display,
        demographics.ethnicity_display,
        elig.birthdate,

        -- time zero and age
        elig.t0_day,
        elig.t0_source,
        elig.age_months_at_t0,
        elig.age_band_at_t0,
        elig.definitive_surgery_day,
        elig.definitive_surgery_source,
        elig.age_months_at_definitive_surgery,

        -- diagnosis evidence
        elig.medulloblastoma_tier1_bool,
        elig.llm_medulloblastoma_bool,
        elig.atrt_confirmed_bool,

        -- ACNS0334 criteria as columns, NULL = not evaluable
        elig.age_under_36_months_at_definitive_surgery,
        elig.no_prior_chemotherapy_bool,
        elig.no_prior_radiation_bool,
        (trial.subject_ref IS NOT NULL)                 AS trial_eligible_bool,

        -- high-risk stratum inputs, adjudicate downstream
        elig.llm_metastatic_bool,
        elig.llm_anaplastic_bool,
        elig.llm_residual_disease_bool,
        elig.llm_residual_tumor_area_cm2_max,
        elig.age_under_8_months_at_t0,

        -- exposures as initial therapy (README section 2)
        elig.methotrexate_any_bool,
        outcome.methotrexate_prior_to_first_event_bool,
        elig.radiation_any_bool,
        outcome.radiation_prior_to_first_event_bool,
        elig.chemo_any_bool,
        outcome.initial_therapy_sequence,
        outcome.protocol_names,

        -- survival (README sections 3 and 5)
        outcome.os_event_bool,
        outcome.death_day,
        outcome.last_known_alive_day,
        outcome.os_end_day,
        outcome.os_days,
        outcome.efs_event_bool,
        outcome.first_event_day,
        outcome.first_event_type,
        outcome.efs_end_day,
        outcome.efs_days,
        outcome.efs_censor_source,

        -- observability
        followup.observation_start_date,
        followup.observation_end_date,
        demographics.encounter_count

FROM    pcx__eligible               AS elig
LEFT JOIN pcx__outcome              AS outcome      ON outcome.subject_ref      = elig.subject_ref
LEFT JOIN demographics                              ON demographics.subject_ref = elig.subject_ref
LEFT JOIN followup                                  ON followup.subject_ref     = elig.subject_ref
LEFT JOIN trial                                     ON trial.subject_ref        = elig.subject_ref
;
