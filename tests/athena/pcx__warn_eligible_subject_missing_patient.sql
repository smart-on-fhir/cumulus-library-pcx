-- ============================================================================
-- Warning: case-definition subject that cannot be aged.
--
--   subject_missing_core_patient   the subject has casedef evidence but no
--                                  core__patient row, so the inner JOIN in
--                                  pcx__eligible_dx drops it silently
--   subject_missing_birthdate      the core__patient row has no birthdate, so
--                                  every age column is NULL and the subject
--                                  leaves the trial-like cohort
-- ============================================================================
CREATE TABLE pcx__warn_eligible_subject_missing_patient AS

WITH casedef_subject AS (
    SELECT  subject_ref,
            MIN(enc_period_start_day)   AS first_day,
            COUNT(DISTINCT code)        AS code_cnt
    FROM    pcx__cohort_casedef
    WHERE   subtype IS NOT NULL
    GROUP BY subject_ref
)

SELECT  'subject_missing_core_patient'                                          AS warn_check,
        CAST(casedef.subject_ref AS VARCHAR)                                    AS subject_ref,
        CONCAT_WS('|',
            CONCAT('first=',    CAST(casedef.first_day AS VARCHAR)),
            CONCAT('codes=',    CAST(casedef.code_cnt AS VARCHAR)))             AS detail
FROM    casedef_subject     AS casedef
LEFT JOIN core__patient     AS pat ON pat.subject_ref = casedef.subject_ref
WHERE   pat.subject_ref IS NULL

UNION ALL

SELECT  'subject_missing_birthdate'                                             AS warn_check,
        CAST(dx.subject_ref AS VARCHAR)                                         AS subject_ref,
        CONCAT_WS('|',
            CONCAT('t0=',           CAST(dx.t0_day AS VARCHAR)),
            CONCAT('llm_age_months=', CAST(dx.llm_age_at_diagnosis_months_min AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_dx    AS dx
WHERE   dx.birthdate IS NULL
;
