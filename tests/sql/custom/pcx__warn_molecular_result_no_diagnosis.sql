-- ============================================================================
-- Warning: a documented molecular group lacks diagnosis evidence or is excluded
-- from the discovery cohort.
--
-- Grain: one row per subject per warning.
-- Only actual molecular groups count; NOT_SUBGROUPED, INDETERMINATE and
-- NONE_OF_THE_ABOVE do not establish a molecular group.
--
-- Checks:
--   molecular_no_llm_diagnosis
--       No diagnosis-task rows exist for the subject.
--   molecular_llm_diagnosis_unspecified
--       Diagnosis-task rows exist, but none names a disease subtype.
--   molecular_no_diagnosis_evidence
--       Neither a named LLM diagnosis nor a tier-1 casedef subtype exists.
--       Tier-2 evidence, including the CHOP roster, is shown separately.
--   molecular_outside_discovery
--       Molecular evidence exists, but the subject is absent from pcx__eligible.
--
-- Multiple warnings may apply to one subject.
-- ============================================================================
CREATE TABLE pcx__warn_molecular_result_no_diagnosis AS
WITH
molecular AS (
    SELECT  subject_ref,
            COUNT(DISTINCT note_ref) AS molecular_note_count,
            ARRAY_JOIN(
                ARRAY_SORT(ARRAY_AGG(DISTINCT molecular_group)),
                ','
            ) AS molecular_groups
    FROM    pcx__llm_molecular_report
    WHERE   subject_ref IS NOT NULL
    AND     molecular_group IN (
                'WNT',
                'SHH',
                'GROUP_3',
                'GROUP_4',
                'NON_WNT_NON_SHH'
            )
    GROUP BY subject_ref
),
diagnosis AS (
    SELECT  subject_ref,
            COUNT(*) AS diagnosis_row_count,
            COUNT(DISTINCT note_ref) AS diagnosis_note_count,
            COUNT(*) FILTER (
                WHERE disease_subtype IS NOT NULL
                AND   TRIM(disease_subtype) <> ''
                AND   disease_subtype <> 'NONE_OF_THE_ABOVE'
            ) AS named_diagnosis_row_count,
            ARRAY_JOIN(
                ARRAY_SORT(
                    ARRAY_AGG(DISTINCT disease_subtype) FILTER (
                        WHERE disease_subtype IS NOT NULL
                        AND   TRIM(disease_subtype) <> ''
                        AND   disease_subtype <> 'NONE_OF_THE_ABOVE'
                    )
                ),
                ','
            ) AS llm_diagnoses
    FROM    pcx__llm_diagnosis_wide
    GROUP BY subject_ref
),
coded AS (
    SELECT  subject_ref,
            COUNT(DISTINCT subtype) FILTER (
                WHERE tier = 1
            ) AS tier1_subtype_count,
            ARRAY_JOIN(
                ARRAY_SORT(
                    ARRAY_AGG(DISTINCT subtype) FILTER (WHERE tier = 1)
                ),
                ','
            ) AS tier1_subtypes,
            ARRAY_JOIN(
                ARRAY_SORT(
                    ARRAY_AGG(DISTINCT subtype) FILTER (WHERE tier = 2)
                ),
                ','
            ) AS tier2_subtypes
    FROM    pcx__cohort_casedef
    WHERE   subtype IS NOT NULL
    AND     TRIM(subtype) <> ''
    GROUP BY subject_ref
),
discovery AS (
    SELECT DISTINCT subject_ref
    FROM pcx__eligible
),
evidence AS (
    SELECT  molecular.subject_ref,
            COALESCE(diagnosis.diagnosis_row_count, 0)
                AS diagnosis_row_count,
            COALESCE(diagnosis.named_diagnosis_row_count, 0)
                AS named_diagnosis_row_count,
            COALESCE(coded.tier1_subtype_count, 0)
                AS tier1_subtype_count,
            (discovery.subject_ref IS NOT NULL)
                AS in_discovery,
            CONCAT_WS('|',
                CONCAT('molecular_groups=', molecular.molecular_groups),
                CONCAT('molecular_notes=',
                       CAST(molecular.molecular_note_count AS VARCHAR)),
                CONCAT('diagnosis_rows=',
                       CAST(COALESCE(diagnosis.diagnosis_row_count, 0)
                            AS VARCHAR)),
                CONCAT('diagnosis_notes=',
                       CAST(COALESCE(diagnosis.diagnosis_note_count, 0)
                            AS VARCHAR)),
                CONCAT('llm_diagnoses=',
                       COALESCE(diagnosis.llm_diagnoses, 'none')),
                CONCAT('tier1_subtypes=',
                       COALESCE(coded.tier1_subtypes, 'none')),
                CONCAT('tier2_subtypes=',
                       COALESCE(coded.tier2_subtypes, 'none')),
                CONCAT('in_discovery=',
                       CAST(discovery.subject_ref IS NOT NULL AS VARCHAR))
            ) AS detail
    FROM    molecular
    LEFT JOIN diagnosis
        ON diagnosis.subject_ref = molecular.subject_ref
    LEFT JOIN coded
        ON coded.subject_ref = molecular.subject_ref
    LEFT JOIN discovery
        ON discovery.subject_ref = molecular.subject_ref
)

SELECT  'molecular_no_llm_diagnosis' AS warn_check,
        CAST(subject_ref AS VARCHAR) AS subject_ref,
        detail
FROM    evidence
WHERE   diagnosis_row_count = 0

UNION ALL

SELECT  'molecular_llm_diagnosis_unspecified' AS warn_check,
        CAST(subject_ref AS VARCHAR) AS subject_ref,
        detail
FROM    evidence
WHERE   diagnosis_row_count > 0
AND     named_diagnosis_row_count = 0

UNION ALL

SELECT  'molecular_no_diagnosis_evidence' AS warn_check,
        CAST(subject_ref AS VARCHAR) AS subject_ref,
        detail
FROM    evidence
WHERE   named_diagnosis_row_count = 0
AND     tier1_subtype_count = 0

UNION ALL

SELECT  'molecular_outside_discovery' AS warn_check,
        CAST(subject_ref AS VARCHAR) AS subject_ref,
        detail
FROM    evidence
WHERE   NOT in_discovery
;