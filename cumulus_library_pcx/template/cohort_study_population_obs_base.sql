CREATE  TABLE   {{ prefix }}__cohort_study_population_obs_base AS
WITH
has_encounter AS (
    SELECT  DISTINCT
            subject_ref,
            encounter_ref
    FROM    {{ prefix }}__cohort_study_population
    WHERE   encounter_ref IS NOT NULL
),
patient_date_range AS (
    SELECT  subject_ref,
            MIN(enc_period_start_day)       AS min_enc_day,
            MAX(enc_period_end_day_filled)  AS max_enc_day
    FROM    {{ prefix }}__cohort_study_population
    WHERE   encounter_ref IS NOT NULL
    GROUP BY subject_ref
)
SELECT  DISTINCT
        obs.category_code                   AS category_code,
        obs.category_system                 AS category_system,

        obs.status                          AS status,
        obs.observation_code                AS observation_code,
        obs.observation_system              AS observation_system,

        obs.interpretation_code             AS interpretation_code,
        obs.interpretation_system           AS interpretation_system,
        obs.interpretation_display          AS interpretation_display,

        obs.effectivedatetime               AS effectivedatetime,
        COALESCE(
            obs.effectivedatetime_day,
            DATE(obs.effectivedatetime))    AS effectivedatetime_day,

        obs.valuecodeableconcept_code       AS valuecodeableconcept_code,
        obs.valuecodeableconcept_system     AS valuecodeableconcept_system,
        obs.valuecodeableconcept_display    AS valuecodeableconcept_display,

        obs.valuequantity_value             AS valuequantity_value,
        obs.valuequantity_comparator        AS valuequantity_comparator,
        obs.valuequantity_unit              AS valuequantity_unit,
        obs.valuequantity_system            AS valuequantity_system,
        obs.valuequantity_code              AS valuequantity_code,

        obs.valuestring                     AS valuestring,
        obs.dataabsentreason_code           AS dataabsentreason_code,

        obs.subject_ref                     AS subject_ref,
        obs.specimen_ref                    AS specimen_ref,
        obs.observation_ref                 AS observation_ref,
        obs.encounter_ref                   AS encounter_ref,
        CASE WHEN enc.encounter_ref IS NOT NULL
        THEN 1 ELSE 0 END                   AS obs_has_encounter
--  patient_date_range is joined INNER, not LEFT, to prune core__observation to
--  study-population subjects at the join rather than after it. This is not a
--  narrowing of the result. Every subject in has_encounter also appears in
--  patient_date_range -- same source table, same encounter_ref IS NOT NULL
--  filter -- so any row that satisfied the old WHERE always has a bounds match,
--  and rows without one could never satisfy it (NULL bounds make BETWEEN NULL).
--  Categories come from the include_obs_category valueset, not a literal, so
--  this table stays a general observation base. Sizing note, measured against
--  the BCH warehouse on 2026-09-08: core__observation is 1.201B rows, of which
--  laboratory is 229.6M (19.1%) and vital-signs is 606.3M (50.5%). Adding a
--  category costs its full share, and a lab-plus-vitals base lands near 836M
--  rows, which is roughly where this build ran out of resources before. When
--  vitals covariates arrive, filter to the specific vital-sign codes the
--  covariates need rather than admitting the whole category.
FROM        core__observation               AS obs
JOIN        {{ prefix }}__include_obs_category AS obs_category
ON          obs.category_code = obs_category.code
JOIN        patient_date_range              AS bounds
ON          obs.subject_ref = bounds.subject_ref
LEFT JOIN   has_encounter                   AS enc
ON          obs.encounter_ref = enc.encounter_ref
AND         obs.subject_ref   = enc.subject_ref
--  Keep an observation when EITHER it links to retained population encounter
--  (enc.encounter_ref IS NOT NULL), OR it does NOT (enc.encounter_ref IS NULL,
--  covering both a true-null encounter_ref AND an encounter_ref pointing at an
--  encounter dropped by the population filters) but its date lands in the
--  patient's active window. The prior `obs.encounter_ref IS NULL` predicate
--  silently dropped dropped-encounter orphans: `enc.encounter_ref IS NULL` rescues
--  them, mirroring the dx anti-join fix.
--  The second branch needs no `enc.encounter_ref IS NULL` guard. The two
--  branches are complementary, so the first already covers the matched case.
WHERE       enc.encounter_ref IS NOT NULL
   OR       COALESCE(obs.effectivedatetime_day, DATE(obs.effectivedatetime))
            BETWEEN bounds.min_enc_day AND bounds.max_enc_day
;
