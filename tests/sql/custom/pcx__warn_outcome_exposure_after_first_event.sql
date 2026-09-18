-- ============================================================================
-- Warning: treatment that started on or after the first event (salvage).
--
-- These subjects have methotrexate or radiation evidence, but the earliest
-- day is not before first_event_day, so the prior-to-first-event flag is
-- FALSE and the exposure is not counted as initial therapy. That is the
-- intended rule (README section 2). The rows are listed because the flag
-- silently depends on event ascertainment: a first event that is really a
-- misdated remission or a pseudo-progression turns initial therapy into
-- salvage. Subjects with no dated event never appear here.
-- ============================================================================
CREATE TABLE pcx__warn_outcome_exposure_after_first_event AS

SELECT  'methotrexate_after_first_event'                                        AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('first=',        CAST(methotrexate_first_day AS VARCHAR)),
            CONCAT('event=',        CAST(first_event_day AS VARCHAR)),
            CONCAT('type=',         first_event_type),
            CONCAT('days=',         CAST(DATE_DIFF('day', first_event_day, methotrexate_first_day) AS VARCHAR)))
                                                                                AS detail
FROM    pcx__outcome_exposure
WHERE   methotrexate_first_day IS NOT NULL
AND     first_event_day IS NOT NULL
AND     NOT methotrexate_prior_to_first_event_bool

UNION ALL

SELECT  'radiation_after_first_event'                                           AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('first=',        CAST(radiation_first_day AS VARCHAR)),
            CONCAT('event=',        CAST(first_event_day AS VARCHAR)),
            CONCAT('type=',         first_event_type),
            CONCAT('days=',         CAST(DATE_DIFF('day', first_event_day, radiation_first_day) AS VARCHAR)))
                                                                                AS detail
FROM    pcx__outcome_exposure
WHERE   radiation_first_day IS NOT NULL
AND     first_event_day IS NOT NULL
AND     NOT radiation_prior_to_first_event_bool
;
