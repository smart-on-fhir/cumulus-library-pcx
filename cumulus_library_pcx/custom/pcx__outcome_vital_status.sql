--  =====================================================================
--  Outcome: vital status, death day, last-known-alive day
--
--  Sources, each kept as its own column and unioned for the earliest death
--  and the latest alive evidence:
--    raw FHIR patient   deceasedBoolean / deceasedDateTime (site ETL must expose them)
--    study population   latest encounter end day
--    LLM patient task   pcx__llm_patient_wide vital_status, death_date, last_known_alive_date
--  A deceased flag without a date gives deceased_bool TRUE and death_day NULL,
--  which the OS table treats as not computable (README section 3).
--  =====================================================================
CREATE  TABLE   pcx__outcome_vital_status AS
WITH
fhir_patient AS (
    SELECT  CONCAT('Patient/', id)          AS subject_ref,
            deceasedBoolean                 AS fhir_deceased_bool,
            DATE(deceasedDateTime)          AS fhir_death_day
    FROM    patient
),
last_encounter AS (
    SELECT  subject_ref,
            MAX(enc_period_end_day_filled)  AS last_encounter_day
    FROM    pcx__cohort_study_population
    GROUP BY subject_ref
),
llm AS (
    SELECT  subject_ref,
            BOOL_OR(vital_status = 'DECEASED')                              AS llm_deceased_bool,
            MIN(CAST(death_date AS DATE))                                   AS llm_death_day,
            MAX(CAST(last_known_alive_date AS DATE))                        AS llm_last_known_alive_day
    FROM    pcx__llm_patient_wide
    GROUP BY subject_ref
),
death_candidate AS (
    SELECT  subject_ref, fhir_death_day AS death_day FROM fhir_patient WHERE fhir_death_day IS NOT NULL
    UNION ALL
    SELECT  subject_ref, llm_death_day  AS death_day FROM llm          WHERE llm_death_day  IS NOT NULL
),
alive_candidate AS (
    SELECT  subject_ref, last_encounter_day      AS alive_day FROM last_encounter WHERE last_encounter_day      IS NOT NULL
    UNION ALL
    SELECT  subject_ref, llm_last_known_alive_day AS alive_day FROM llm          WHERE llm_last_known_alive_day IS NOT NULL
),
death_first AS (
    SELECT subject_ref, MIN(death_day) AS death_day FROM death_candidate GROUP BY subject_ref
),
alive_last AS (
    SELECT subject_ref, MAX(alive_day) AS last_known_alive_day FROM alive_candidate GROUP BY subject_ref
)
SELECT  elig.subject_ref,
        elig.t0_day,
        CASE
            WHEN fhir.fhir_deceased_bool        THEN TRUE
            WHEN death_first.death_day IS NOT NULL THEN TRUE
            WHEN llm.llm_deceased_bool          THEN TRUE
            ELSE FALSE
        END                                     AS deceased_bool,
        death_first.death_day,
        alive_last.last_known_alive_day,
        fhir.fhir_deceased_bool,
        fhir.fhir_death_day,
        last_encounter.last_encounter_day,
        llm.llm_deceased_bool,
        llm.llm_death_day,
        llm.llm_last_known_alive_day
FROM    pcx__eligible  AS elig
LEFT JOIN fhir_patient          AS fhir           ON fhir.subject_ref           = elig.subject_ref
LEFT JOIN last_encounter                          ON last_encounter.subject_ref = elig.subject_ref
LEFT JOIN llm                                     ON llm.subject_ref            = elig.subject_ref
LEFT JOIN death_first                             ON death_first.subject_ref    = elig.subject_ref
LEFT JOIN alive_last                              ON alive_last.subject_ref     = elig.subject_ref
;