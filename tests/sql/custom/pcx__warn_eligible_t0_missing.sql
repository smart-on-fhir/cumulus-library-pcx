-- ============================================================================
-- Warning: case-definition subject with no time zero.
--
-- pcx__eligible_dx sets t0_day from the first TIER 1 medulloblastoma casedef
-- encounter. A subject with only tier 2 codes (C71.6 / 191.6 cerebellum) or
-- only LLM diagnosis evidence has a NULL t0_day, a NULL age band, and is
-- dropped from pcx__eligible_trial. When the LLM names medulloblastoma but no
-- tier 1 code exists, the casedef valueset is the likely gap (ICD-O 9473/3,
-- 9475/3 to 9478/3 are not in spreadsheet/casedef.csv).
-- ============================================================================
CREATE TABLE pcx__warn_eligible_t0_missing AS

WITH tier2 AS (
    SELECT  subject_ref,
            COUNT(DISTINCT code)                AS tier2_code_cnt,
            MIN(enc_period_start_day)           AS tier2_first_day
    FROM    pcx__cohort_casedef
    WHERE   subtype = 'medulloblastoma'
    AND     tier = 2
    GROUP BY subject_ref
)

SELECT  CASE
            WHEN dx.llm_medulloblastoma_bool            THEN 't0_missing_llm_medulloblastoma'
            WHEN tier2.subject_ref IS NOT NULL          THEN 't0_missing_tier2_only'
            ELSE                                             't0_missing_no_medulloblastoma_evidence'
        END                                                                     AS warn_check,
        CAST(dx.subject_ref AS VARCHAR)                                         AS subject_ref,
        CONCAT_WS('|',
            CONCAT('tier2_codes=',      CAST(COALESCE(tier2.tier2_code_cnt, 0) AS VARCHAR)),
            CONCAT('tier2_first=',      CAST(tier2.tier2_first_day AS VARCHAR)),
            CONCAT('llm_mb=',           CAST(dx.llm_medulloblastoma_bool AS VARCHAR)),
            CONCAT('llm_atrt=',         CAST(dx.llm_atrt_bool AS VARCHAR)),
            CONCAT('llm_dx_gold=',      CAST(dx.llm_diagnosis_gold_day_min AS VARCHAR)),
            CONCAT('atrt_tier1=',       CAST(dx.atrt_tier1_bool AS VARCHAR)))  AS detail
FROM    pcx__eligible_dx    AS dx
LEFT JOIN tier2             ON tier2.subject_ref = dx.subject_ref
WHERE   dx.t0_day IS NULL
;
