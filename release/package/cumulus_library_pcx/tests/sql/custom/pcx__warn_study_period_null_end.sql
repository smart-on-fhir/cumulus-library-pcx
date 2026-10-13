-- ============================================================================
-- Warning: study period encounters with no end day.
-- cohort_study_period keeps them (a NULL end never fails the window check) and
-- cohort_study_population fills the end with the start day, so an open-ended
-- encounter can qualify a patient and set the population span on its own.
--
--   null_end_in_window   started inside include_study_period
--   null_end_history     started before period_start (kept by include_history)
-- ============================================================================
CREATE TABLE pcx__warn_study_period_null_end AS
WITH include AS (
    SELECT  COALESCE(DATE(period_start), DATE('2000-01-01'))    AS period_start
    FROM    pcx__include_study_period
)
SELECT  CASE
            WHEN sp.period_start_day < include.period_start             THEN 'null_end_history'
            ELSE                                                             'null_end_in_window'
        END                                                                     AS warn_check,
        CAST(sp.subject_ref AS VARCHAR)                                         AS subject_ref,
        CONCAT_WS('|',
            CONCAT('encounter=',    CAST(sp.encounter_ref AS VARCHAR)),
            CONCAT('start=',        CAST(sp.period_start_day AS VARCHAR)),
            CONCAT('ordinal=',      CAST(sp.period_ordinal AS VARCHAR)))        AS detail
FROM    pcx__cohort_study_period    AS sp,
        include
WHERE   sp.period_end_day IS NULL
;
