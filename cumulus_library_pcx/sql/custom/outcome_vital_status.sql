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
--  A month or year LLM date is used at the middle of its period (the 15th of
--  the month, July 1 of the year), since a survival duration needs a day.
--  death_day_imputed_bool / last_known_alive_day_imputed_bool say when the
--  winning day is such a mid-point. The per-source llm_* columns keep the day
--  as recorded (the first day of the period).
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
-- every dated LLM death or alive statement, at the middle of a month or year
llm_dated AS (
    SELECT  subject_ref,
            'death'                                                         AS kind,
            CASE death_day_precision
                WHEN 'MONTH' THEN CAST(death_day + INTERVAL '14' DAY AS DATE)
                WHEN 'YEAR'  THEN CAST(death_day + INTERVAL '6' MONTH AS DATE)
                ELSE              death_day
            END                                                             AS day,
            death_day_precision = 'DAY'                                     AS exact_bool
    FROM    pcx__llm_survival_timeline_wide
    WHERE   death_day IS NOT NULL
    UNION ALL
    SELECT  subject_ref,
            'death',
            CASE event_day_precision
                WHEN 'MONTH' THEN CAST(event_day + INTERVAL '14' DAY AS DATE)
                WHEN 'YEAR'  THEN CAST(event_day + INTERVAL '6' MONTH AS DATE)
                ELSE              event_day
            END,
            event_day_precision = 'DAY'
    FROM    pcx__llm_event_wide
    WHERE   event_type = 'DECEASED'
    AND     event_day IS NOT NULL
    UNION ALL
    SELECT  subject_ref,
            'alive',
            CASE last_known_alive_day_precision
                WHEN 'MONTH' THEN CAST(last_known_alive_day + INTERVAL '14' DAY AS DATE)
                WHEN 'YEAR'  THEN CAST(last_known_alive_day + INTERVAL '6' MONTH AS DATE)
                ELSE              last_known_alive_day
            END,
            last_known_alive_day_precision = 'DAY'
    FROM    pcx__llm_survival_timeline_wide
    WHERE   last_known_alive_day IS NOT NULL
),
death_candidate AS (
    SELECT  subject_ref, fhir_death_day AS death_day, TRUE AS exact_bool FROM fhir_patient WHERE fhir_death_day IS NOT NULL
    UNION ALL
    SELECT  subject_ref, day, exact_bool FROM llm_dated WHERE kind = 'death'
),
alive_candidate AS (
    SELECT  subject_ref, last_encounter_day AS alive_day, TRUE AS exact_bool FROM last_encounter WHERE last_encounter_day IS NOT NULL
    UNION ALL
    SELECT  subject_ref, day, exact_bool FROM llm_dated WHERE kind = 'alive'
),
death_first AS (
    SELECT  subject_ref,
            MIN(death_day)                                                  AS death_day
    FROM    death_candidate
    GROUP BY subject_ref
),
death_imputed AS (
    SELECT  death_first.subject_ref,
            NOT BOOL_OR(death_candidate.exact_bool)                         AS death_day_imputed_bool
    FROM    death_first
    JOIN    death_candidate
      ON    death_candidate.subject_ref = death_first.subject_ref
     AND    death_candidate.death_day   = death_first.death_day
    GROUP BY death_first.subject_ref
),
alive_last AS (
    SELECT  subject_ref,
            MAX(alive_day)                                                  AS last_known_alive_day
    FROM    alive_candidate
    GROUP BY subject_ref
),
alive_imputed AS (
    SELECT  alive_last.subject_ref,
            NOT BOOL_OR(alive_candidate.exact_bool)                         AS last_known_alive_day_imputed_bool
    FROM    alive_last
    JOIN    alive_candidate
      ON    alive_candidate.subject_ref = alive_last.subject_ref
     AND    alive_candidate.alive_day   = alive_last.last_known_alive_day
    GROUP BY alive_last.subject_ref
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
        death_imputed.death_day_imputed_bool,
        alive_last.last_known_alive_day,
        alive_imputed.last_known_alive_day_imputed_bool,
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
LEFT JOIN death_imputed                           ON death_imputed.subject_ref  = elig.subject_ref
LEFT JOIN alive_last                              ON alive_last.subject_ref     = elig.subject_ref
LEFT JOIN alive_imputed                           ON alive_imputed.subject_ref  = elig.subject_ref
;