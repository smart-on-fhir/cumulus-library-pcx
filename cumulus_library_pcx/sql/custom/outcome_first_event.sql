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
--  Dates (2026-10-22):
--    A month or year event date covers its whole period. The first event
--    falls between first_event_earliest_day (earliest start of any dated
--    event) and first_event_latest_day (earliest end of any dated event), so
--    an order comparison is certain only outside that range.
--    first_event_day is the day used for durations: a coarse date at the
--    middle of its period (the 15th of the month, July 1 of the year), with
--    first_event_day_imputed_bool TRUE. The per-type first days use the same
--    day. A death counts at death_day from outcome_vital_status.
--    An undated progression, recurrence or second malignancy happened on or
--    before the date of its note (pcx__llm_note_date, FHIR metadata):
--      note dated on or after first_event_latest_day   a restatement of the
--                                     dated event, ignored
--                                     (undated_event_restated_cnt)
--      note dated earlier, note undated, or no dated event at all
--                                     an event of unknown timing
--                                     (undated_event_cnt)
--
--  A documented event is not the same as a dated event:
--    dated_event_bool             a dated event exists, first_event_day is the first
--    undated_event_cnt            undated mentions of unknown timing, NULL when none
--    event_timing_uncertain_bool  undated_event_cnt is not NULL. The undated mention
--                                 may be earlier than the dated first event, so the
--                                 EFS interval waits for reconciliation.
--                                 first_event_day is still kept as evidence.
--    death_undated_bool           deceased, but no death date from any source. The
--                                 patient was alive for every dated event, so an
--                                 undated death never moves the first event earlier.
--    event_documented_bool        any of the three above, the EFS event flag
--  =====================================================================
CREATE  TABLE   pcx__outcome_first_event AS
WITH
llm_event AS (
    SELECT  event.subject_ref,
            event.event_type,
            event.event_day,
            event.event_day_precision,
            note_day.note_date
    FROM    pcx__llm_event_wide     AS event
    LEFT JOIN pcx__llm_note_date    AS note_day
      ON    note_day.subject_ref = event.subject_ref
     AND    note_day.note_ref    = event.note_ref
    WHERE   event.event_type IN ('PROGRESSION', 'RECURRENCE', 'SECOND_MALIGNANCY')
),
-- every dated event with the range of days it covers and its day for durations
candidate AS (
    SELECT  subject_ref,
            event_type,
            event_day                                                       AS earliest_day,
            CASE event_day_precision
                WHEN 'MONTH' THEN CAST(event_day + INTERVAL '1' MONTH - INTERVAL '1' DAY AS DATE)
                WHEN 'YEAR'  THEN CAST(event_day + INTERVAL '1' YEAR - INTERVAL '1' DAY AS DATE)
                ELSE              event_day
            END                                                             AS latest_day,
            CASE event_day_precision
                WHEN 'MONTH' THEN CAST(event_day + INTERVAL '14' DAY AS DATE)
                WHEN 'YEAR'  THEN CAST(event_day + INTERVAL '6' MONTH AS DATE)
                ELSE              event_day
            END                                                             AS event_day,
            event_day_precision = 'DAY'                                     AS exact_bool
    FROM    llm_event
    WHERE   event_day IS NOT NULL
    UNION ALL
    SELECT  subject_ref,
            'DECEASED',
            death_day,
            death_day,
            death_day,
            NOT death_day_imputed_bool
    FROM    pcx__outcome_vital_status
    WHERE   death_day IS NOT NULL
),
first_day AS (
    SELECT  subject_ref,
            MIN(event_day)                                                          AS first_event_day,
            MIN(earliest_day)                                                       AS first_event_earliest_day,
            MIN(latest_day)                                                         AS first_event_latest_day,
            MIN(CASE WHEN event_type = 'PROGRESSION'       THEN event_day END)      AS progression_first_day,
            MIN(CASE WHEN event_type = 'RECURRENCE'        THEN event_day END)      AS recurrence_first_day,
            MIN(CASE WHEN event_type = 'SECOND_MALIGNANCY' THEN event_day END)      AS second_malignancy_first_day,
            MIN(CASE WHEN event_type = 'DECEASED'          THEN event_day END)      AS death_first_day
    FROM    candidate
    GROUP BY subject_ref
),
first_type AS (
    SELECT  candidate.subject_ref,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(DISTINCT candidate.event_type)), ',')   AS first_event_type,
            NOT BOOL_OR(candidate.exact_bool)                                       AS first_event_day_imputed_bool
    FROM    candidate
    JOIN    first_day
    ON      first_day.subject_ref = candidate.subject_ref
    AND     first_day.first_event_day = candidate.event_day
    GROUP BY candidate.subject_ref
),
undated AS (
    SELECT  llm_event.subject_ref,
            COUNT(*) FILTER (WHERE NOT COALESCE(llm_event.note_date >= first_day.first_event_latest_day, FALSE))
                                                                                    AS undated_event_cnt,
            COUNT(*) FILTER (WHERE llm_event.note_date >= first_day.first_event_latest_day)
                                                                                    AS undated_event_restated_cnt
    FROM    llm_event
    LEFT JOIN first_day ON first_day.subject_ref = llm_event.subject_ref
    WHERE   llm_event.event_day IS NULL
    GROUP BY llm_event.subject_ref
),
subject AS (
    SELECT  elig.subject_ref,
            elig.t0_day,
            first_day.first_event_day,
            first_day.first_event_earliest_day,
            first_day.first_event_latest_day,
            first_type.first_event_day_imputed_bool,
            first_type.first_event_type,
            (first_day.first_event_day IS NOT NULL)                                 AS dated_event_bool,
            COALESCE(undated.undated_event_cnt > 0, FALSE)                          AS event_timing_uncertain_bool,
            (first_day.death_first_day IS NULL AND vital.deceased_bool)            AS death_undated_bool,
            first_day.progression_first_day,
            first_day.recurrence_first_day,
            first_day.second_malignancy_first_day,
            vital.death_day,
            NULLIF(undated.undated_event_cnt, 0)                                    AS undated_event_cnt,
            NULLIF(undated.undated_event_restated_cnt, 0)                           AS undated_event_restated_cnt,
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
