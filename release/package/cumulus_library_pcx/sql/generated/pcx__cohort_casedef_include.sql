CREATE  TABLE   pcx__cohort_casedef_include AS
SELECT  DISTINCT
        candidate.*
FROM    pcx__cohort_casedef_candidate AS candidate
WHERE   NOT EXISTS (
            SELECT  1
            FROM    pcx__cohort_casedef_exclude AS exclude
            WHERE   exclude.subject_ref = candidate.subject_ref
        )
;