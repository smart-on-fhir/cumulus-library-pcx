--  =====================================================================
--  Outcome: first event
--
--  "First event" per README section 2: the first event that would count in an
--  EFS calculation, that is progression, recurrence, secondary malignancy or
--  death. REMISSION, INITIAL_DIAGNOSIS and SECOND_PRIMARY are not counted
--  (SECOND_PRIMARY is pending the EFS event-list decision in section 5).
--  Death comes only from outcome_vital_status, which reconciles FHIR, the
--  survival_timeline task and event-task DECEASED mentions. A structured death
--  date counts even when no note names it, and OS and EFS see the same death.
--
--  A documented event is not the same as a dated event:
--    dated_event_bool             a dated event exists, first_event_day is the earliest
--    undated_event_cnt            progression, recurrence or second malignancy
--                                 mentions with no date, NULL when there are none
--    event_timing_uncertain_bool  undated_event_cnt is not NULL. The undated mention
--                                 may be earlier than first_event_day or repeat it,
--                                 so the EFS interval waits for reconciliation.
--                                 first_event_day is still kept as evidence.
--    death_undated_bool           deceased, but no death date from any source. The
--                                 patient was alive for every dated event, so an
--                                 undated death never moves the first event earlier.
--    event_documented_bool        any of the three above, the EFS event flag
--  =====================================================================
CREATE  TABLE   pcx__outcome_first_event AS
WITH
llm_event AS (
    SELECT  subject_ref,
            event_type,
            event_day
    FROM    pcx__llm_event_wide
    WHERE   event_type IN ('PROGRESSION', 'RECURRENCE', 'SECOND_MALIGNANCY')
),
candidate AS (
    SELECT  subject_ref, event_type, event_day
    FROM    llm_event
    WHERE   event_day IS NOT NULL
    UNION ALL
    SELECT  subject_ref, 'DECEASED' AS event_type, death_day AS event_day
    FROM    pcx__outcome_vital_status
    WHERE   death_day IS NOT NULL
),
first_day AS (
    SELECT  subject_ref,
            MIN(event_day)                                                          AS first_event_day,
            MIN(CASE WHEN event_type = 'PROGRESSION'       THEN event_day END)      AS progression_first_day,
            MIN(CASE WHEN event_type = 'RECURRENCE'        THEN event_day END)      AS recurrence_first_day,
            MIN(CASE WHEN event_type = 'SECOND_MALIGNANCY' THEN event_day END)      AS second_malignancy_first_day,
            MIN(CASE WHEN event_type = 'DECEASED'          THEN event_day END)      AS death_first_day
    FROM    candidate
    GROUP BY subject_ref
),
first_type_distinct AS (
    SELECT  DISTINCT
            candidate.subject_ref,
            candidate.event_type
    FROM    candidate
    JOIN    first_day
    ON      first_day.subject_ref = candidate.subject_ref
    AND     first_day.first_event_day = candidate.event_day
),
first_type AS (
    SELECT  subject_ref,
            ARRAY_JOIN(ARRAY_AGG(event_type ORDER BY event_type), ',')              AS first_event_type
    FROM    first_type_distinct
    GROUP BY subject_ref
),
undated AS (
    SELECT  subject_ref,
            COUNT(*)                        AS undated_event_cnt
    FROM    llm_event
    WHERE   event_day IS NULL
    GROUP BY subject_ref
),
subject AS (
    SELECT  elig.subject_ref,
            elig.t0_day,
            first_day.first_event_day,
            first_type.first_event_type,
            (first_day.first_event_day IS NOT NULL)                                 AS dated_event_bool,
            (undated.undated_event_cnt IS NOT NULL)                                 AS event_timing_uncertain_bool,
            (first_day.death_first_day IS NULL AND vital.deceased_bool)            AS death_undated_bool,
            first_day.progression_first_day,
            first_day.recurrence_first_day,
            first_day.second_malignancy_first_day,
            vital.death_day,
            undated.undated_event_cnt,
            DATE_DIFF('day', elig.t0_day, first_day.first_event_day)                AS days_t0_to_first_event
    FROM    pcx__eligible              AS elig
    LEFT JOIN pcx__outcome_vital_status AS vital ON vital.subject_ref      = elig.subject_ref
    LEFT JOIN first_day                                   ON first_day.subject_ref  = elig.subject_ref
    LEFT JOIN first_type                                  ON first_type.subject_ref = elig.subject_ref
    LEFT JOIN undated                                     ON undated.subject_ref    = elig.subject_ref
)
SELECT  subject.*,
        (dated_event_bool OR event_timing_uncertain_bool OR death_undated_bool)     AS event_documented_bool
FROM    subject
;
