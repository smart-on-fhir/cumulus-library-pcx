-- ============================================================================
-- Warning: two different time zeros for the same subject.
--
-- pcx__cohort_casedef anchors days_since / casedef_period (pre, peri, post)
-- on enc_period_start_day_min, the first casedef encounter of ANY subtype and
-- ANY tier. pcx__eligible_dx anchors t0_day on the first TIER 1
-- medulloblastoma encounter. When the two differ, note sampling temporality
-- and eligibility age are measured from different days.
--
--   t0_anchor_casedef_earlier   a tier 2/3 or ATRT encounter precedes t0_day
--   t0_anchor_casedef_later     should not happen, t0_day is itself a casedef encounter
-- ============================================================================
CREATE TABLE pcx__warn_eligible_t0_anchor_disagree AS

WITH casedef_anchor AS (
    SELECT  subject_ref,
            MIN(enc_period_start_day_min)       AS casedef_anchor_day
    FROM    pcx__cohort_casedef
    GROUP BY subject_ref
)

SELECT  CASE
            WHEN anchor.casedef_anchor_day < dx.t0_day  THEN 't0_anchor_casedef_earlier'
            ELSE                                             't0_anchor_casedef_later'
        END                                                                     AS warn_check,
        CAST(dx.subject_ref AS VARCHAR)                                         AS subject_ref,
        CONCAT_WS('|',
            CONCAT('t0=',               CAST(dx.t0_day AS VARCHAR)),
            CONCAT('casedef_anchor=',   CAST(anchor.casedef_anchor_day AS VARCHAR)),
            CONCAT('days=',             CAST(DATE_DIFF('day', anchor.casedef_anchor_day, dx.t0_day) AS VARCHAR)))
                                                                                AS detail
FROM    pcx__eligible_dx    AS dx
JOIN    casedef_anchor      AS anchor  ON anchor.subject_ref = dx.subject_ref
WHERE   dx.t0_day IS NOT NULL
AND     anchor.casedef_anchor_day <> dx.t0_day
;
