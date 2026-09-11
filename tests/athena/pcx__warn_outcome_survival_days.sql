-- ============================================================================
-- Warning: survival intervals that cannot be right.
--
--   os_days_negative        death or last-alive day before time zero
--   os_days_zero            no follow-up after time zero at all
--   os_days_null_deceased   deceased, but no death day so OS is not computable
--   os_days_null_alive      alive, but no last-known-alive day
--   efs_days_negative       first event or censor day before time zero
--   efs_after_os            efs_end_day later than os_end_day (an event dated
--                           after death, or censoring past last contact)
-- ============================================================================
CREATE TABLE pcx__warn_outcome_survival_days AS

SELECT  CASE
            WHEN os_days < 0                                    THEN 'os_days_negative'
            WHEN os_days = 0                                    THEN 'os_days_zero'
            WHEN os_days IS NULL AND os_event_bool              THEN 'os_days_null_deceased'
            WHEN os_days IS NULL AND NOT os_event_bool          THEN 'os_days_null_alive'
            WHEN efs_days < 0                                   THEN 'efs_days_negative'
            WHEN efs_end_day > os_end_day                       THEN 'efs_after_os'
        END                                                                     AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('t0=',           CAST(t0_day AS VARCHAR)),
            CONCAT('os_end=',       CAST(os_end_day AS VARCHAR)),
            CONCAT('os_days=',      CAST(os_days AS VARCHAR)),
            CONCAT('os_event=',     CAST(os_event_bool AS VARCHAR)),
            CONCAT('efs_end=',      CAST(efs_end_day AS VARCHAR)),
            CONCAT('efs_days=',     CAST(efs_days AS VARCHAR)),
            CONCAT('efs_censor=',   efs_censor_source))                         AS detail
FROM    pcx__outcome
WHERE   t0_day IS NOT NULL
AND     (   os_days < 0
        OR  os_days = 0
        OR  os_days IS NULL
        OR  efs_days < 0
        OR  efs_end_day > os_end_day
        )
;
