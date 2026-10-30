-- ============================================================================
-- Warning: a documented molecular group without a matching diagnosis.
--
-- Only real groups count (WNT, SHH, GROUP_3, GROUP_4, NON_WNT_NON_SHH), all
-- medulloblastoma groups. NOT_SUBGROUPED, INDETERMINATE and NONE_OF_THE_ABOVE
-- are ignored. Diagnosis evidence is a named LLM disease_subtype (any note of
-- pcx__llm_diagnosis_wide) or a tier 1 casedef code. Tier 2 codes, the CHOP
-- roster included, are evidence only and appear in the detail.
--
--   molecular_no_diagnosis_evidence          no named LLM diagnosis and no
--                                            tier 1 casedef code
--   molecular_diagnosis_not_medulloblastoma  diagnosis evidence exists, but
--                                            none of it is medulloblastoma
--                                            (ATRT, ETMR, pineoblastoma, ...)
--   molecular_outside_discovery              the subject is not in
--                                            pcx__eligible, so client tables
--                                            drop its molecular result
--
-- The first two are exclusive. outside_discovery can add a second row.
-- ============================================================================
CREATE TABLE pcx__warn_molecular_result_no_diagnosis AS

WITH molecular AS (
    SELECT  subject_ref,
            COUNT(DISTINCT note_ref)                                        AS molecular_note_cnt,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(DISTINCT molecular_group)), ',') AS molecular_groups
    FROM    pcx__llm_molecular_report
    WHERE   molecular_group IN ('WNT', 'SHH', 'GROUP_3', 'GROUP_4', 'NON_WNT_NON_SHH')
    GROUP BY subject_ref
),
llm_dx AS (
    SELECT  subject_ref,
            COUNT(DISTINCT note_ref)                                        AS dx_note_cnt,
            BOOL_OR(disease_subtype <> 'NONE_OF_THE_ABOVE')                 AS named_bool,
            BOOL_OR(disease_subtype = 'MEDULLOBLASTOMA')                    AS medulloblastoma_bool,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(DISTINCT disease_subtype)
                FILTER (WHERE disease_subtype <> 'NONE_OF_THE_ABOVE')), ',') AS llm_subtypes
    FROM    pcx__llm_diagnosis_wide
    GROUP BY subject_ref
),
casedef AS (
    SELECT  subject_ref,
            BOOL_OR(tier = 1)                                               AS tier1_bool,
            BOOL_OR(tier = 1 AND subtype = 'medulloblastoma')               AS tier1_medulloblastoma_bool,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(DISTINCT subtype) FILTER (WHERE tier = 1)), ',') AS tier1_subtypes,
            ARRAY_JOIN(ARRAY_SORT(ARRAY_AGG(DISTINCT subtype) FILTER (WHERE tier = 2)), ',') AS tier2_subtypes
    FROM    pcx__cohort_casedef
    WHERE   subtype IS NOT NULL
    GROUP BY subject_ref
),
flagged AS (
    SELECT  molecular.subject_ref,
            CASE
                WHEN llm_dx.named_bool IS DISTINCT FROM TRUE
                 AND casedef.tier1_bool IS DISTINCT FROM TRUE                   THEN 'molecular_no_diagnosis_evidence'
                WHEN llm_dx.medulloblastoma_bool IS DISTINCT FROM TRUE
                 AND casedef.tier1_medulloblastoma_bool IS DISTINCT FROM TRUE   THEN 'molecular_diagnosis_not_medulloblastoma'
            END                                                             AS dx_check,
            eligible.subject_ref IS NULL                                    AS outside_discovery_bool,
            CONCAT_WS('|',
                CONCAT('molecular_groups=', molecular.molecular_groups),
                CONCAT('molecular_notes=',  CAST(molecular.molecular_note_cnt AS VARCHAR)),
                CONCAT('dx_notes=',         CAST(COALESCE(llm_dx.dx_note_cnt, 0) AS VARCHAR)),
                CONCAT('llm_subtypes=',     COALESCE(llm_dx.llm_subtypes, 'none')),
                CONCAT('tier1_subtypes=',   COALESCE(casedef.tier1_subtypes, 'none')),
                CONCAT('tier2_subtypes=',   COALESCE(casedef.tier2_subtypes, 'none')),
                CONCAT('in_discovery=',     CAST(eligible.subject_ref IS NOT NULL AS VARCHAR)))  AS detail
    FROM    molecular
    LEFT JOIN llm_dx            ON llm_dx.subject_ref   = molecular.subject_ref
    LEFT JOIN casedef           ON casedef.subject_ref  = molecular.subject_ref
    LEFT JOIN pcx__eligible     AS eligible ON eligible.subject_ref = molecular.subject_ref
)

SELECT  dx_check                        AS warn_check,
        CAST(subject_ref AS VARCHAR)    AS subject_ref,
        detail
FROM    flagged
WHERE   dx_check IS NOT NULL
UNION ALL
SELECT  'molecular_outside_discovery'   AS warn_check,
        CAST(subject_ref AS VARCHAR)    AS subject_ref,
        detail
FROM    flagged
WHERE   outside_discovery_bool
;
