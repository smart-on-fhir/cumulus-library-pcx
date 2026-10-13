-- ============================================================================
-- QA: study period encounters outside the configured window (must be empty).
--
--   end_before_start        known end day earlier than the start day
--   start_not_before_today  start day today or in the future
--   start_after_window      start day after include_study_period.period_end
--   end_after_window        known end day after include_study_period.period_end
--   start_before_window     start day before period_start and history is not included
-- ============================================================================
CREATE TABLE pcx__qa_study_period_bounds AS
WITH include AS (
    SELECT  COALESCE(DATE(period_start), DATE('2000-01-01'))    AS period_start,
            COALESCE(DATE(period_end),   CURRENT_DATE)          AS period_end,
            include_history
    FROM    pcx__include_study_period
)
SELECT  CASE
            WHEN sp.period_end_day < sp.period_start_day                THEN 'end_before_start'
            WHEN sp.period_start_day >= CURRENT_DATE                    THEN 'start_not_before_today'
            WHEN sp.period_start_day > include.period_end               THEN 'start_after_window'
            WHEN sp.period_end_day > include.period_end                 THEN 'end_after_window'
            WHEN sp.period_start_day < include.period_start
             AND NOT include.include_history                            THEN 'start_before_window'
        END                                                                     AS qa_check,
        CAST(sp.subject_ref AS VARCHAR)                                         AS subject_ref,
        CONCAT_WS('|',
            CONCAT('encounter=',    CAST(sp.encounter_ref AS VARCHAR)),
            CONCAT('start=',        CAST(sp.period_start_day AS VARCHAR)),
            CONCAT('end=',          CAST(sp.period_end_day AS VARCHAR)),
            CONCAT('window=',       CAST(include.period_start AS VARCHAR), '..', CAST(include.period_end AS VARCHAR)),
            CONCAT('history=',      CAST(include.include_history AS VARCHAR)))  AS detail
FROM    pcx__cohort_study_period    AS sp,
        include
WHERE   sp.period_end_day < sp.period_start_day
OR      sp.period_start_day >= CURRENT_DATE
OR      sp.period_start_day > include.period_end
OR      sp.period_end_day > include.period_end
OR      (sp.period_start_day < include.period_start AND NOT include.include_history)
;
