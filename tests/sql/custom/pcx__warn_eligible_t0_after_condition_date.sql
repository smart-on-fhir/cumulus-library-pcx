-- ============================================================================
-- Warning: time zero trails the condition's own dates.
--
-- t0_day is an ENCOUNTER start day (the encounter the tier 1 medulloblastoma
-- condition was linked to). The FHIR Condition also carries onsetDateTime and
-- recordedDate. When either precedes t0_day by more than 30 days the linked
-- encounter is probably not the diagnosis encounter (date-rescue linkage or a
-- late-coded diagnosis), and age_months_at_t0 is measured too late.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_t0_after_condition_date AS

WITH condition_day AS (
    SELECT  subject_ref,
            MIN(dx_onset_date)          AS onset_first_day,
            MIN(dx_recorded_date)       AS recorded_first_day
    FROM    pcx__cohort_casedef_dx
    WHERE   subtype = 'medulloblastoma'
    AND     tier = 1
    GROUP BY subject_ref
),
earliest AS (
    SELECT  subject_ref,
            onset_first_day,
            recorded_first_day,
            LEAST(COALESCE(onset_first_day, recorded_first_day),
                  COALESCE(recorded_first_day, onset_first_day))    AS condition_first_day
    FROM    condition_day
)

SELECT  't0_after_condition_date'                                               AS warn_check,
        CAST(dx.subject_ref AS VARCHAR)                                         AS subject_ref,
        CONCAT_WS('|',
            CONCAT('t0=',           CAST(dx.t0_day AS VARCHAR)),
            CONCAT('onset=',        CAST(earliest.onset_first_day AS VARCHAR)),
            CONCAT('recorded=',     CAST(earliest.recorded_first_day AS VARCHAR)),
            CONCAT('days=',         CAST(DATE_DIFF('day', earliest.condition_first_day, dx.t0_day) AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_dx    AS dx
JOIN    earliest            ON earliest.subject_ref = dx.subject_ref
WHERE   dx.t0_day IS NOT NULL
AND     earliest.condition_first_day IS NOT NULL
AND     DATE_DIFF('day', earliest.condition_first_day, dx.t0_day) > 30
;
