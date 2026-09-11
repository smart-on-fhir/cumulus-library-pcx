-- ============================================================================
-- Warning: age lands within one month of the 36-month ACNS0334 cut-off.
--
-- Ages are DATE_DIFF('month', birthdate, day). In Athena that counts month
-- boundaries crossed, not completed months, so a child born on the 31st can
-- read one month older than a completed-months calculation. Subjects at
-- 35, 36 or 37 months change trial-cohort membership under either reading and
-- deserve a manual look. Two anchors are checked: t0_day and the definitive
-- surgery day (the day ACNS0334 actually uses).
-- ============================================================================
CREATE TABLE pcx__warn_eligible_age_near_36_month_boundary AS

SELECT  'age_at_t0_near_36_months'                                              AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('months=',       CAST(age_months_at_t0 AS VARCHAR)),
            CONCAT('birthdate=',    CAST(birthdate AS VARCHAR)),
            CONCAT('t0=',           CAST(t0_day AS VARCHAR)))                   AS detail
FROM    pcx__eligible
WHERE   age_months_at_t0 BETWEEN 35 AND 37

UNION ALL

SELECT  'age_at_definitive_surgery_near_36_months'                              AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('months=',       CAST(age_months_at_definitive_surgery AS VARCHAR)),
            CONCAT('birthdate=',    CAST(birthdate AS VARCHAR)),
            CONCAT('surgery=',      CAST(definitive_surgery_day AS VARCHAR)),
            CONCAT('source=',       definitive_surgery_source))                 AS detail
FROM    pcx__eligible
WHERE   age_months_at_definitive_surgery BETWEEN 35 AND 37
;
