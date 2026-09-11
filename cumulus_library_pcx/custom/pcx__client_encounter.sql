-- ================================================
-- Grain: one row per subject_ref x encounter_ref.
--
-- Encounter spine for client subjects, placed relative to time zero, with
-- per-encounter coded-evidence flags from pcx__cohort_variable_wide (one row
-- per encounter_ref_link, TRUE or NULL per variable). PCX has no encounter
-- class/type valuesets, so utilization here is disease-specific evidence,
-- not admit/ED/outpatient classification.
-- ================================================
CREATE TABLE pcx__client_encounter AS
WITH
encounter AS (
    SELECT  sp.subject_ref,
            sp.encounter_ref,
            MIN(sp.enc_period_ordinal)          AS enc_period_ordinal,
            MIN(sp.enc_period_start_day)        AS enc_period_start_day,
            MAX(sp.enc_period_end_day)          AS enc_period_end_day,
            MAX(sp.enc_period_end_day_filled)   AS enc_period_end_day_filled,
            MIN(sp.age_at_visit)                AS age_at_visit
    FROM    pcx__cohort_study_population AS sp
    JOIN    pcx__client_subject AS subject
      ON    sp.subject_ref = subject.subject_ref
    WHERE   sp.encounter_ref IS NOT NULL
    AND     sp.enc_period_start_day IS NOT NULL
    GROUP BY
            sp.subject_ref,
            sp.encounter_ref
),

-- Relative period from the case definition (pre / peri / post first casedef match).
casedef AS (
    SELECT  subject_ref,
            encounter_ref_link,
            MIN(days_since)                     AS casedef_days_since,
            MIN(casedef_period)                 AS casedef_period
    FROM    pcx__cohort_casedef
    GROUP BY subject_ref, encounter_ref_link
),

evidence AS (
    SELECT  wide.encounter_ref_link,
            wide.dx_medulloblastoma                                     AS dx_medulloblastoma_bool,
            wide.dx_atrt                                                AS dx_atrt_bool,
            wide.dx_brain_cancer                                        AS dx_brain_cancer_bool,
            wide.dx_radiation                                           AS dx_radiation_bool,
            wide.dx_methotrexate_toxic                                  AS dx_methotrexate_toxic_bool,
            wide.rx_contrast_methotrexate                               AS rx_methotrexate_bool,
            (wide.rx_chemo_carboplatin OR wide.rx_chemo_cisplatin OR wide.rx_chemo_cyclophosphamide
             OR wide.rx_chemo_etoposide OR wide.rx_chemo_thiotepa OR wide.rx_chemo_vincristine)
                                                                        AS rx_chemo_bool,
            wide.proc_craniotomy                                        AS proc_craniotomy_bool,
            wide.proc_radiation                                         AS proc_radiation_bool,
            (wide.lab_absolute_neutrophil_count OR wide.lab_alt OR wide.lab_ast OR wide.lab_creatinine
             OR wide.lab_hemoglobin OR wide.lab_platelets OR wide.lab_total_bilirubin)
                                                                        AS lab_organ_function_bool,
            (wide.lab_folate OR wide.lab_folate_rbc OR wide.lab_folate_whole_blood
             OR wide.lab_folate_unspecified OR wide.lab_folate_interpretation)
                                                                        AS lab_folate_bool
    FROM    pcx__cohort_variable_wide AS wide
)

SELECT  encounter.subject_ref,
        encounter.encounter_ref,
        encounter.enc_period_ordinal,
        encounter.enc_period_start_day,
        encounter.enc_period_end_day,
        encounter.enc_period_end_day_filled,
        encounter.age_at_visit,
        DATE_DIFF('day', subject.t0_day, encounter.enc_period_start_day)    AS days_since_t0,
        casedef.casedef_days_since,
        casedef.casedef_period,
        -- coded evidence, TRUE or NULL as in pcx__cohort_variable_wide
        evidence.dx_medulloblastoma_bool,
        evidence.dx_atrt_bool,
        evidence.dx_brain_cancer_bool,
        evidence.dx_radiation_bool,
        evidence.dx_methotrexate_toxic_bool,
        evidence.rx_methotrexate_bool,
        evidence.rx_chemo_bool,
        evidence.proc_craniotomy_bool,
        evidence.proc_radiation_bool,
        evidence.lab_organ_function_bool,
        evidence.lab_folate_bool
FROM    encounter
JOIN    pcx__client_subject AS subject
  ON    encounter.subject_ref = subject.subject_ref
LEFT JOIN casedef
  ON    encounter.subject_ref  = casedef.subject_ref
 AND    encounter.encounter_ref = casedef.encounter_ref_link
LEFT JOIN evidence
  ON    encounter.encounter_ref = evidence.encounter_ref_link
;
