--  =====================================================================
--  Outcome: vital status, death day, last-known-alive day
--
--  Sources, each kept as its own column and unioned for the earliest death
--  and the latest alive evidence:
--    raw FHIR patient   deceasedBoolean / deceasedDateTime (site ETL must expose them)
--    study population   latest encounter end day
--    LLM survival_timeline task pcx__llm_survival_timeline_wide vital_status, death_date, last_known_alive_date
--    LLM event task     pcx__llm_event_wide event_type DECEASED, dated or not
--  This is the one place deaths are reconciled. pcx__outcome_first_event takes
--  death from here, so OS and EFS always see the same death.
--  A deceased flag without a date gives deceased_bool TRUE and death_day NULL,
--  which the OS table treats as not computable (README section 3).
--  Every date is plausible, from 1980-01-01 to the build day. LLM days are
--  already NULL outside it (sql/template/date_macros.sql.jinja). Here the
--  FHIR deceasedDateTime and the last encounter day get the same window, so
--  an implausible death date leaves the subject deceased with death_day NULL,
--  and no duration is computed from it. A deceasedDateTime counts as the FHIR
--  deceased flag even when its date is cleared (FHIR sends deceasedBoolean or
--  deceasedDateTime, not both). pcx__warn_outcome_vital_status_conflict lists
--  each cleared FHIR death date as fhir_death_day_implausible.
--  =====================================================================
CREATE  TABLE   pcx__outcome_vital_status AS
WITH
fhir_patient_raw AS (
    SELECT  CONCAT('Patient/', id)          AS subject_ref,
            CASE
                WHEN deceasedDateTime IS NOT NULL THEN TRUE
                ELSE deceasedBoolean
            END                             AS fhir_deceased_bool,
            DATE(FROM_ISO8601_TIMESTAMP(deceasedDateTime)) AS fhir_death_day_raw
    FROM    patient
),
fhir_patient AS (
    SELECT  subject_ref,
            fhir_deceased_bool,
            CASE
                WHEN fhir_death_day_raw BETWEEN DATE '1980-01-01' AND CURRENT_DATE THEN fhir_death_day_raw
            END                             AS fhir_death_day
    FROM    fhir_patient_raw
),
last_encounter AS (
    SELECT  subject_ref,
            MAX(enc_period_end_day_filled)  AS last_encounter_day
    FROM    pcx__cohort_study_population
    WHERE   enc_period_end_day_filled BETWEEN DATE '1980-01-01' AND CURRENT_DATE
    GROUP BY subject_ref
),
llm AS (
    SELECT  subject_ref,
            BOOL_OR(vital_status = 'DECEASED')                              AS llm_deceased_bool,
            MIN(death_day)                                                  AS llm_death_day,
            MAX(last_known_alive_day)                                       AS llm_last_known_alive_day
    FROM    pcx__llm_survival_timeline_wide
    GROUP BY subject_ref
),
llm_event AS (
    SELECT  subject_ref,
            TRUE                                                            AS llm_event_deceased_bool,
            MIN(event_day)                                                  AS llm_event_death_day
    FROM    pcx__llm_event_wide
    WHERE   event_type = 'DECEASED'
    GROUP BY subject_ref
),
death_candidate AS (
    SELECT  subject_ref, fhir_death_day      AS death_day FROM fhir_patient WHERE fhir_death_day      IS NOT NULL
    UNION ALL
    SELECT  subject_ref, llm_death_day       AS death_day FROM llm          WHERE llm_death_day       IS NOT NULL
    UNION ALL
    SELECT  subject_ref, llm_event_death_day AS death_day FROM llm_event    WHERE llm_event_death_day IS NOT NULL
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
            WHEN llm_event.llm_event_deceased_bool THEN TRUE
            ELSE FALSE
        END                                     AS deceased_bool,
        death_first.death_day,
        alive_last.last_known_alive_day,
        fhir.fhir_deceased_bool,
        fhir.fhir_death_day,
        last_encounter.last_encounter_day,
        llm.llm_deceased_bool,
        llm.llm_death_day,
        llm.llm_last_known_alive_day,
        llm_event.llm_event_deceased_bool,
        llm_event.llm_event_death_day
FROM    pcx__eligible  AS elig
LEFT JOIN fhir_patient          AS fhir           ON fhir.subject_ref           = elig.subject_ref
LEFT JOIN last_encounter                          ON last_encounter.subject_ref = elig.subject_ref
LEFT JOIN llm                                     ON llm.subject_ref            = elig.subject_ref
LEFT JOIN llm_event                               ON llm_event.subject_ref      = elig.subject_ref
LEFT JOIN death_first                             ON death_first.subject_ref    = elig.subject_ref
LEFT JOIN alive_last                              ON alive_last.subject_ref     = elig.subject_ref
;