-- ============================================================================
-- QA: study population subjects that fail include_utilization (must be empty).
-- Recomputes the thresholds cohort_study_population applied, from its own rows.
--
--   periods_below_min   fewer distinct utilization periods than enc_min
--   periods_above_max   more distinct utilization periods than enc_max
--   days_below_min      first start to last (filled) end shorter than days_min
--   days_above_max      first start to last (filled) end longer than days_max
-- ============================================================================
CREATE TABLE pcx__qa_study_population_utilization AS
WITH per_subject AS (
    SELECT  subject_ref,
            COUNT(DISTINCT enc_period_ordinal)                                  AS cnt_period,
            DATE_DIFF('day', MIN(enc_period_start_day), MAX(enc_period_end_day_filled))
                                                                                AS cnt_days
    FROM    pcx__cohort_study_population
    GROUP BY subject_ref
)
SELECT  CASE
            WHEN per_subject.cnt_period < include.enc_min                   THEN 'periods_below_min'
            WHEN per_subject.cnt_period > include.enc_max                   THEN 'periods_above_max'
            WHEN per_subject.cnt_days   < include.days_min                  THEN 'days_below_min'
            WHEN per_subject.cnt_days   > include.days_max                  THEN 'days_above_max'
        END                                                                     AS qa_check,
        CAST(per_subject.subject_ref AS VARCHAR)                                AS subject_ref,
        CONCAT_WS('|',
            CONCAT('periods=',      CAST(per_subject.cnt_period AS VARCHAR)),
            CONCAT('days=',         CAST(per_subject.cnt_days AS VARCHAR)),
            CONCAT('enc=',          CAST(include.enc_min AS VARCHAR), '..', CAST(include.enc_max AS VARCHAR)),
            CONCAT('days_window=',  CAST(include.days_min AS VARCHAR), '..', CAST(include.days_max AS VARCHAR)))
                                                                                AS detail
FROM    per_subject,
        pcx__include_utilization    AS include
WHERE   NOT (per_subject.cnt_period BETWEEN include.enc_min  AND include.enc_max)
OR      NOT (per_subject.cnt_days   BETWEEN include.days_min AND include.days_max)
;
