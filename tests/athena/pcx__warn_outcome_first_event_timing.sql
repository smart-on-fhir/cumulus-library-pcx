-- ============================================================================
-- Warning: first-event evidence that undermines the EFS clock.
--
--   event_before_t0             first_event_day precedes time zero (a
--                               progression or recurrence dated before the
--                               coded diagnosis means t0_day lags, or the
--                               event belongs to an earlier tumor)
--   event_after_death           a dated progression / recurrence / second
--                               malignancy later than death_day
--   undated_events_only         events exist but none has a date, so
--                               any_event_bool is FALSE and the subject is
--                               censored as event-free
--   first_event_multiple_types  two event types share the first event day
-- ============================================================================
CREATE TABLE pcx__warn_outcome_first_event_timing AS

WITH dated_event AS (
    SELECT  subject_ref,
            event_type,
            CAST(event_date AS DATE)    AS event_day
    FROM    pcx__llm_event_wide
    WHERE   event_type IN ('PROGRESSION', 'RECURRENCE', 'SECOND_MALIGNANCY')
    AND     event_date IS NOT NULL
)

SELECT  'event_before_t0'                                                       AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('event=',    CAST(first_event_day AS VARCHAR)),
            CONCAT('type=',     first_event_type),
            CONCAT('t0=',       CAST(t0_day AS VARCHAR)),
            CONCAT('days=',     CAST(days_t0_to_first_event AS VARCHAR)))       AS detail
FROM    pcx__outcome_first_event
WHERE   first_event_day IS NOT NULL
AND     t0_day IS NOT NULL
AND     first_event_day < t0_day

UNION ALL

SELECT  'event_after_death'                                                     AS warn_check,
        CAST(event.subject_ref AS VARCHAR)                                      AS subject_ref,
        CONCAT_WS('|',
            CONCAT('event=',    CAST(event.event_day AS VARCHAR)),
            CONCAT('type=',     event.event_type),
            CONCAT('death=',    CAST(first_event.death_day AS VARCHAR)),
            CONCAT('days=',     CAST(DATE_DIFF('day', first_event.death_day, event.event_day) AS VARCHAR)))
                                                                                AS detail
FROM    dated_event                 AS event
JOIN    pcx__outcome_first_event    AS first_event ON first_event.subject_ref = event.subject_ref
WHERE   first_event.death_day IS NOT NULL
AND     event.event_day > first_event.death_day

UNION ALL

SELECT  'undated_events_only'                                                   AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('undated=',  CAST(undated_event_cnt AS VARCHAR)),
            CONCAT('t0=',       CAST(t0_day AS VARCHAR)))                       AS detail
FROM    pcx__outcome_first_event
WHERE   NOT any_event_bool
AND     undated_event_cnt > 0

UNION ALL

SELECT  'first_event_multiple_types'                                            AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('event=',    CAST(first_event_day AS VARCHAR)),
            CONCAT('types=',    first_event_type))                              AS detail
FROM    pcx__outcome_first_event
WHERE   first_event_type LIKE '%,%'
;
