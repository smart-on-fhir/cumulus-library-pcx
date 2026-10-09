CREATE  TABLE   pcx__sample_casedef_peri AS
WITH
encounter_casedef AS (
    SELECT  DISTINCT
            etl.group_name,
            casedef.subject_ref,
            casedef.encounter_ref_link,
            casedef.days_since,
            casedef.ordinal_since,
            casedef.enc_period_start_day_min,
            population.enc_period_start_day,
            casedef.enc_period_ordinal_min,
            population.enc_period_ordinal
    FROM    (SELECT encounter_id, MIN(group_name) AS group_name
             FROM etl__completion_encounters GROUP BY encounter_id)              AS etl,
            pcx__cohort_casedef            AS casedef,
            pcx__cohort_study_population   AS population
    WHERE   casedef.encounter_ref_link   = population.encounter_ref
    AND     casedef.subject_ref = population.subject_ref
    AND     casedef.encounter_ref_link   = concat('Encounter/', etl.encounter_id)
    AND     casedef.peri
),
encounter_doc AS (
    SELECT  DISTINCT
            'documentreference' AS fhir_resource,
            casedef.*,
            CASE
                WHEN    (doc.doc_author_day    IS NOT NULL)
                THEN     doc.doc_author_day
                WHEN    (doc.doc_date          IS NOT NULL)
                THEN     doc.doc_date
                ELSE    casedef.enc_period_start_day
                END AS  sort_by_date,
            doc.doc_author_day          AS note_author_date,
            doc.doc_date                AS note_date,
            doc.doc_type_system         AS note_system,
            doc.doc_type_code           AS note_code,
            doc.doc_type_display        AS note_display,
            doc.documentreference_ref   AS note_ref
    FROM    encounter_casedef           AS casedef,
            pcx__cohort_study_population_doc AS doc
    WHERE   casedef.encounter_ref_link   = doc.encounter_ref_link
    AND     casedef.subject_ref = doc.subject_ref
    AND     doc.aux_has_text
),
encounter_diag AS (
    SELECT  DISTINCT
            'diagnosticreport' AS fhir_resource,
            casedef.*,
            CASE
                WHEN   (diag.diag_effectivedatetime_day IS NOT NULL)
                THEN    diag.diag_effectivedatetime_day
                WHEN   (diag.diag_effectiveperiod_start_day IS NOT NULL)
                THEN    diag.diag_effectiveperiod_start_day
                ELSE    casedef.enc_period_start_day
                END AS  sort_by_date,
            diag.diag_effectivedatetime_day     AS note_author_date,
            diag.diag_effectiveperiod_start_day AS note_date,
            diag.diag_system                    AS note_system,
            diag.diag_code                      AS note_code,
            diag.diag_display                   AS note_display,
            diag.diagnosticreport_ref           AS note_ref
    FROM    encounter_casedef                   AS casedef,
            pcx__cohort_study_population_diag AS diag
    WHERE   casedef.encounter_ref_link   = diag.encounter_ref_link
    AND     casedef.subject_ref = diag.subject_ref
    AND     diag.aux_has_text
),
encounter_note AS
(
    SELECT * FROM encounter_doc
    UNION ALL
    SELECT * FROM encounter_diag
),
encounter_note_uniq AS
(
    -- One ordering key per subject/note even when linked encounters supply different dates.
    SELECT  subject_ref,
            note_ref,
            MIN(sort_by_date) AS sort_by_date
    FROM    encounter_note
    GROUP BY subject_ref, note_ref
),
ordered AS (
    SELECT  DISTINCT
            subject_ref,
            note_ref,
            sort_by_date,
            ROW_NUMBER() OVER (
                PARTITION   BY  subject_ref
                ORDER       BY  sort_by_date,
                                note_ref
            )   AS note_ordinal
    FROM    encounter_note_uniq
)
SELECT  DISTINCT
        encounter_note.*,
        ordered.note_ordinal
FROM    ordered
JOIN    encounter_note
ON      ordered.note_ref = encounter_note.note_ref
AND     ordered.subject_ref = encounter_note.subject_ref
;
