-- ============================================================================
-- Warning: medulloblastoma and ATRT both claimed for one subject.
--
-- pcx__eligible sets atrt_confirmed_bool from EITHER a tier 1 ATRT code OR
-- any single LLM note saying ATRT (BOOL_OR across notes), and that excludes
-- the subject from pcx__eligible_trial. One misread note is enough. The
-- detail shows how many LLM notes back each subtype so a minority ATRT claim
-- stands out from a genuine reclassification.
--
--   subtype_conflict_structured   tier 1 medulloblastoma AND tier 1 ATRT codes
--   subtype_conflict_llm          LLM notes name both subtypes
--   subtype_conflict_cross        structured tier 1 medulloblastoma, LLM ATRT only
-- ============================================================================
CREATE TABLE pcx__warn_eligible_dx_subtype_conflict AS

WITH llm_votes AS (
    SELECT  subject_ref,
            COUNT(DISTINCT CASE WHEN disease_subtype = 'MEDULLOBLASTOMA' THEN note_ref END)  AS mb_note_cnt,
            COUNT(DISTINCT CASE WHEN disease_subtype = 'ATRT'            THEN note_ref END)  AS atrt_note_cnt,
            COUNT(DISTINCT note_ref)                                                          AS note_cnt
    FROM    pcx__llm_diagnosis_wide
    GROUP BY subject_ref
),
flagged AS (
    SELECT  dx.subject_ref,
            dx.medulloblastoma_tier1_bool,
            dx.atrt_tier1_bool,
            dx.atrt_first_day,
            dx.t0_day,
            COALESCE(votes.mb_note_cnt, 0)      AS mb_note_cnt,
            COALESCE(votes.atrt_note_cnt, 0)    AS atrt_note_cnt,
            COALESCE(votes.note_cnt, 0)         AS note_cnt,
            CASE
                WHEN dx.medulloblastoma_tier1_bool AND dx.atrt_tier1_bool           THEN 'subtype_conflict_structured'
                WHEN votes.mb_note_cnt > 0 AND votes.atrt_note_cnt > 0              THEN 'subtype_conflict_llm'
                WHEN dx.medulloblastoma_tier1_bool AND votes.atrt_note_cnt > 0      THEN 'subtype_conflict_cross'
            END                                 AS warn_check
    FROM    pcx__eligible_dx    AS dx
    LEFT JOIN llm_votes         AS votes ON votes.subject_ref = dx.subject_ref
)

SELECT  warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('mb_tier1=',         CAST(medulloblastoma_tier1_bool AS VARCHAR)),
            CONCAT('atrt_tier1=',       CAST(atrt_tier1_bool AS VARCHAR)),
            CONCAT('atrt_first=',       CAST(atrt_first_day AS VARCHAR)),
            CONCAT('t0=',               CAST(t0_day AS VARCHAR)),
            CONCAT('llm_mb_notes=',     CAST(mb_note_cnt AS VARCHAR)),
            CONCAT('llm_atrt_notes=',   CAST(atrt_note_cnt AS VARCHAR)),
            CONCAT('llm_notes=',        CAST(note_cnt AS VARCHAR)))             AS detail
FROM    flagged
WHERE   warn_check IS NOT NULL
;
