-- ============================================================================
-- Grain: one row per subject_ref x variable x outcome_date.
--
-- Long form of the outcome stage for every client subject. Survival rows
-- carry the origin as outcome_date and the end as outcome_end_date so the
-- duration is reproducible from the row itself. Nothing here is re-derived:
-- every value comes from pcx__outcome and its component tables.
-- ============================================================================
CREATE TABLE pcx__client_outcome AS
WITH events AS (

-- ------------------------------------------------------------------------
-- pcx__outcome (overall survival, README section 3)
--   outcome_date = t0_day, outcome_end_date = death or last known alive
--   value_number = os_days, value_boolean = died, value_text = end reason
-- ------------------------------------------------------------------------
SELECT  subject_ref,
        'overall_survival'                  AS variable,
        t0_day                              AS outcome_date,
        os_end_day                          AS outcome_end_date,
        CASE WHEN os_event_bool THEN 'DEATH' ELSE 'LAST_KNOWN_ALIVE' END
                                            AS value_text,
        CAST(os_days AS DOUBLE)             AS value_number,
        os_event_bool                       AS value_boolean,
        CAST(NULL AS BIGINT)                AS episode_number,
        'pcx__outcome'                      AS source_table
FROM    pcx__outcome
WHERE   t0_day IS NOT NULL

UNION ALL

-- ------------------------------------------------------------------------
-- pcx__outcome (event-free survival, README section 5, PROVISIONAL)
--   value_text = efs_censor_source, which says provisional on censored rows
-- ------------------------------------------------------------------------
SELECT  subject_ref,
        'event_free_survival'               AS variable,
        t0_day                              AS outcome_date,
        efs_end_day                         AS outcome_end_date,
        efs_censor_source                   AS value_text,
        CAST(efs_days AS DOUBLE)            AS value_number,
        efs_event_bool                      AS value_boolean,
        CAST(NULL AS BIGINT)                AS episode_number,
        'pcx__outcome'                      AS source_table
FROM    pcx__outcome
WHERE   t0_day IS NOT NULL

UNION ALL

-- ------------------------------------------------------------------------
-- pcx__outcome_vital_status (death)
-- ------------------------------------------------------------------------
SELECT  subject_ref,
        'death'                             AS variable,
        death_day                           AS outcome_date,
        CAST(NULL AS DATE)                  AS outcome_end_date,
        CAST(NULL AS VARCHAR)               AS value_text,
        CAST(NULL AS DOUBLE)                AS value_number,
        deceased_bool                       AS value_boolean,
        CAST(NULL AS BIGINT)                AS episode_number,
        'pcx__outcome_vital_status'         AS source_table
FROM    pcx__outcome_vital_status
WHERE   deceased_bool

UNION ALL

-- ------------------------------------------------------------------------
-- pcx__outcome_vital_status (last known alive)
-- ------------------------------------------------------------------------
SELECT  subject_ref,
        'last_known_alive'                  AS variable,
        last_known_alive_day                AS outcome_date,
        CAST(NULL AS DATE)                  AS outcome_end_date,
        CAST(NULL AS VARCHAR)               AS value_text,
        CAST(NULL AS DOUBLE)                AS value_number,
        TRUE                                AS value_boolean,
        CAST(NULL AS BIGINT)                AS episode_number,
        'pcx__outcome_vital_status'         AS source_table
FROM    pcx__outcome_vital_status
WHERE   last_known_alive_day IS NOT NULL

UNION ALL

-- ------------------------------------------------------------------------
-- pcx__outcome_first_event (first EFS-type event)
--   value_text = event type(s) on that day, value_number = days from t0
-- ------------------------------------------------------------------------
SELECT  subject_ref,
        'first_event'                       AS variable,
        first_event_day                     AS outcome_date,
        CAST(NULL AS DATE)                  AS outcome_end_date,
        first_event_type                    AS value_text,
        CAST(days_t0_to_first_event AS DOUBLE)
                                            AS value_number,
        any_event_bool                      AS value_boolean,
        CAST(NULL AS BIGINT)                AS episode_number,
        'pcx__outcome_first_event'          AS source_table
FROM    pcx__outcome_first_event
WHERE   first_event_day IS NOT NULL

UNION ALL

-- ------------------------------------------------------------------------
-- pcx__outcome_first_event (per-type first days)
-- ------------------------------------------------------------------------
SELECT  subject_ref, 'progression' AS variable, progression_first_day AS outcome_date,
        CAST(NULL AS DATE) AS outcome_end_date, CAST(NULL AS VARCHAR) AS value_text,
        CAST(NULL AS DOUBLE) AS value_number, TRUE AS value_boolean,
        CAST(NULL AS BIGINT) AS episode_number, 'pcx__outcome_first_event' AS source_table
FROM    pcx__outcome_first_event
WHERE   progression_first_day IS NOT NULL

UNION ALL

SELECT  subject_ref, 'recurrence' AS variable, recurrence_first_day AS outcome_date,
        CAST(NULL AS DATE) AS outcome_end_date, CAST(NULL AS VARCHAR) AS value_text,
        CAST(NULL AS DOUBLE) AS value_number, TRUE AS value_boolean,
        CAST(NULL AS BIGINT) AS episode_number, 'pcx__outcome_first_event' AS source_table
FROM    pcx__outcome_first_event
WHERE   recurrence_first_day IS NOT NULL

UNION ALL

SELECT  subject_ref, 'second_malignancy' AS variable, second_malignancy_first_day AS outcome_date,
        CAST(NULL AS DATE) AS outcome_end_date, CAST(NULL AS VARCHAR) AS value_text,
        CAST(NULL AS DOUBLE) AS value_number, TRUE AS value_boolean,
        CAST(NULL AS BIGINT) AS episode_number, 'pcx__outcome_first_event' AS source_table
FROM    pcx__outcome_first_event
WHERE   second_malignancy_first_day IS NOT NULL
)

-- ------------------------------------------------------------------------
-- Date plausibility, applied once for every branch above.
-- A date outside [1980-01-01, today] is not a real observation - it is a
-- placeholder, a typo, or a mis-parsed partial date - so it is reported as
-- unknown rather than passed to downstream survival arithmetic. Rows are
-- never dropped, only their dates are cleared.
-- ------------------------------------------------------------------------
SELECT  events.subject_ref,
        events.variable,
        CASE
            WHEN events.outcome_date     BETWEEN DATE '1980-01-01' AND CURRENT_DATE
            THEN events.outcome_date
            ELSE NULL
        END                                 AS outcome_date,
        CASE
            WHEN events.outcome_end_date BETWEEN DATE '1980-01-01' AND CURRENT_DATE
            THEN events.outcome_end_date
            ELSE NULL
        END                                 AS outcome_end_date,
        events.value_text,
        events.value_number,
        events.value_boolean,
        events.episode_number,
        events.source_table
FROM    events
JOIN    pcx__client_subject AS subject
  ON    events.subject_ref = subject.subject_ref
;
