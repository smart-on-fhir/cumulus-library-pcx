
-- Dependency tree:
--  cohort_study_period
--  cohort_study_population
--  cohort_study_population_obs_base
--  cohort_study_population_obs (this table)
--  =====================================================================
--  Link Observation to study_population
--  priorities:

--  A. encounter_ref maps to a retained study_population encounter
--     (obs_has_encounter = 1, set in cohort_study_population_obs_base)
--  B. effectivedatetime present AND obs_has_encounter = 0 (encounter_ref is NULL
--     *or* not retained study_population encounter) -- date-rescue for orphans.
--     Orphan admission (incl. dropped-encounter labs) is handled upstream in
--     cohort_study_population_obs_base: here we just route obs_has_encounter = 0.

-- TIE-BREAK exact-start-date
--  1. encounter starts on the date-mapped day
--  2. narrowest window
--  3. start closest to the date-mapped day
--  4. ordinal
--  5. encounter_ref
-- =====================================================================
CREATE  TABLE   pcx__cohort_study_population_obs AS
WITH
has_encounter AS (
    SELECT  DISTINCT
            subject_ref,
            encounter_ref,
            enc_period_ordinal,
            enc_period_start_day,
            enc_period_end_day_filled
    FROM    pcx__cohort_study_population
    WHERE   encounter_ref IS NOT NULL
),
-- Priority A: encounter_ref maps to retained study_population encounter
by_encounter AS (
    SELECT  obs.*,
            obs.encounter_ref AS encounter_ref_link,
            'encounter_ref'   AS encounter_ref_link_col
    FROM    pcx__cohort_study_population_obs_base AS obs
    WHERE   obs.obs_has_encounter = 1
),

-- Priority B candidates: effectivedatetime present AND the observation is NOT on
-- retained study_population encounter.
date_candidates AS (
    SELECT  DISTINCT
            observation_ref,
            subject_ref,
            effectivedatetime_day
    FROM    pcx__cohort_study_population_obs_base
    WHERE   obs_has_encounter = 0
    AND     effectivedatetime_day IS NOT NULL
),
date_candidates_ranked AS (
    SELECT  obs.observation_ref,
            sp.encounter_ref AS encounter_ref_link,
            ROW_NUMBER() OVER (
                PARTITION BY obs.observation_ref
                ORDER BY
                    -- Exact start, narrowest window, closest start, ordinal, stable id.
                    CASE WHEN obs.effectivedatetime_day = sp.enc_period_start_day THEN 0 ELSE 1 END,
                    DATE_DIFF('day', sp.enc_period_start_day, sp.enc_period_end_day_filled) ASC,
                    ABS(DATE_DIFF('day', sp.enc_period_start_day, obs.effectivedatetime_day)) ASC,
                    sp.enc_period_ordinal ASC,
                    sp.encounter_ref ASC
            ) AS obs_link_rank
    FROM    date_candidates AS obs
    JOIN    has_encounter AS sp
    ON      sp.subject_ref = obs.subject_ref
    AND     obs.effectivedatetime_day BETWEEN sp.enc_period_start_day AND sp.enc_period_end_day_filled
),
date_candidates_links AS (
    SELECT  observation_ref,
            encounter_ref_link
    FROM    date_candidates_ranked
    WHERE   obs_link_rank = 1
),
by_effectivedate AS (
    SELECT  obs.*,
            link.encounter_ref_link,
            'effectivedatetime'     AS encounter_ref_link_col
    FROM    date_candidates_links   AS link
    JOIN    pcx__cohort_study_population_obs_base AS obs
    ON      obs.observation_ref = link.observation_ref
    WHERE   obs.effectivedatetime_day IS NOT NULL
),
union_link AS (
    SELECT * FROM by_encounter
    UNION ALL
    SELECT * FROM by_effectivedate
)
-- obs_* column names are the contract read by cohort_variable_union_obs and fhir_reference
SELECT  DISTINCT
        CASE
            WHEN obs.observation_system = 'http://loinc.org'
            THEN loinc_name.consumer_name
            ELSE NULL
        END                                 AS obs_observation_display,

        obs.observation_code                AS obs_observation_code,
        obs.observation_system              AS obs_observation_system,

        obs.valuecodeableconcept_code       AS obs_concept_code,
        obs.valuecodeableconcept_display    AS obs_concept_display,
        obs.valuecodeableconcept_system     AS obs_concept_system,

        obs.effectivedatetime               AS obs_effectivedate,
        obs.effectivedatetime_day           AS obs_effectivedate_day,

        obs.interpretation_code             AS obs_interpretation_code,
        obs.interpretation_system           AS obs_interpretation_system,
        obs.interpretation_display          AS obs_interpretation_display,

        obs.valuequantity_value             AS obs_valuequantity_value,
        obs.valuequantity_comparator        AS obs_valuequantity_comparator,
        obs.valuequantity_unit              AS obs_valuequantity_unit,
        obs.valuequantity_system            AS obs_valuequantity_system,
        obs.valuequantity_code              AS obs_valuequantity_code,

        obs.valuestring                     AS obs_valuestring,
        obs.dataabsentreason_code           AS obs_dataabsentreason,
        obs.status                          AS obs_status,

        obs.observation_ref,
        obs.specimen_ref,

        obs.subject_ref,
        obs.encounter_ref,
        obs.encounter_ref_link,
        obs.encounter_ref_link_col
FROM    union_link AS obs
LEFT    JOIN    loinc.consumer_name AS loinc_name
ON      obs.observation_code = loinc_name.loinc_number
;
