CREATE  TABLE   pcx__cohort_variable_union AS
WITH
select_union AS
(
	SELECT 'dx_atrt'	 AS variable, code, display, system, subject_ref, encounter_ref_link, condition_ref AS resource_ref FROM pcx__cohort_dx_atrt UNION ALL
	SELECT 'dx_brain_cancer'	 AS variable, code, display, system, subject_ref, encounter_ref_link, condition_ref AS resource_ref FROM pcx__cohort_dx_brain_cancer UNION ALL
	SELECT 'dx_medulloblastoma'	 AS variable, code, display, system, subject_ref, encounter_ref_link, condition_ref AS resource_ref FROM pcx__cohort_dx_medulloblastoma UNION ALL
	SELECT 'dx_methotrexate_toxic'	 AS variable, code, display, system, subject_ref, encounter_ref_link, condition_ref AS resource_ref FROM pcx__cohort_dx_methotrexate_toxic UNION ALL
	SELECT 'dx_radiation'	 AS variable, code, display, system, subject_ref, encounter_ref_link, condition_ref AS resource_ref FROM pcx__cohort_dx_radiation UNION ALL
	SELECT 'lab_absolute_neutrophil_count'	 AS variable, code, display, system, subject_ref, encounter_ref_link, observation_ref AS resource_ref FROM pcx__cohort_lab_absolute_neutrophil_count UNION ALL
	SELECT 'lab_alt'	 AS variable, code, display, system, subject_ref, encounter_ref_link, observation_ref AS resource_ref FROM pcx__cohort_lab_alt UNION ALL
	SELECT 'lab_ast'	 AS variable, code, display, system, subject_ref, encounter_ref_link, observation_ref AS resource_ref FROM pcx__cohort_lab_ast UNION ALL
	SELECT 'lab_creatinine'	 AS variable, code, display, system, subject_ref, encounter_ref_link, observation_ref AS resource_ref FROM pcx__cohort_lab_creatinine UNION ALL
	SELECT 'lab_hemoglobin'	 AS variable, code, display, system, subject_ref, encounter_ref_link, observation_ref AS resource_ref FROM pcx__cohort_lab_hemoglobin UNION ALL
	SELECT 'lab_platelets'	 AS variable, code, display, system, subject_ref, encounter_ref_link, observation_ref AS resource_ref FROM pcx__cohort_lab_platelets UNION ALL
	SELECT 'lab_total_bilirubin'	 AS variable, code, display, system, subject_ref, encounter_ref_link, observation_ref AS resource_ref FROM pcx__cohort_lab_total_bilirubin UNION ALL
	SELECT 'proc_craniotomy'	 AS variable, code, display, system, subject_ref, encounter_ref_link, procedure_ref AS resource_ref FROM pcx__cohort_proc_craniotomy UNION ALL
	SELECT 'proc_radiation'	 AS variable, code, display, system, subject_ref, encounter_ref_link, procedure_ref AS resource_ref FROM pcx__cohort_proc_radiation UNION ALL
	SELECT 'rx_chemo_carboplatin'	 AS variable, code, display, system, subject_ref, encounter_ref_link, medicationrequest_ref AS resource_ref FROM pcx__cohort_rx_chemo_carboplatin UNION ALL
	SELECT 'rx_chemo_cisplatin'	 AS variable, code, display, system, subject_ref, encounter_ref_link, medicationrequest_ref AS resource_ref FROM pcx__cohort_rx_chemo_cisplatin UNION ALL
	SELECT 'rx_chemo_cyclophosphamide'	 AS variable, code, display, system, subject_ref, encounter_ref_link, medicationrequest_ref AS resource_ref FROM pcx__cohort_rx_chemo_cyclophosphamide UNION ALL
	SELECT 'rx_chemo_etoposide'	 AS variable, code, display, system, subject_ref, encounter_ref_link, medicationrequest_ref AS resource_ref FROM pcx__cohort_rx_chemo_etoposide UNION ALL
	SELECT 'rx_chemo_thiotepa'	 AS variable, code, display, system, subject_ref, encounter_ref_link, medicationrequest_ref AS resource_ref FROM pcx__cohort_rx_chemo_thiotepa UNION ALL
	SELECT 'rx_chemo_vincristine'	 AS variable, code, display, system, subject_ref, encounter_ref_link, medicationrequest_ref AS resource_ref FROM pcx__cohort_rx_chemo_vincristine UNION ALL
	SELECT 'rx_contrast_methotrexate'	 AS variable, code, display, system, subject_ref, encounter_ref_link, medicationrequest_ref AS resource_ref FROM pcx__cohort_rx_contrast_methotrexate
),
-- Collapse semantically identical evidence rows before joining to the
-- encounter spine. The evidence key is variable + coding + resource +
-- retained encounter link. ``display`` is descriptive metadata, not part
-- of the evidence identity, valuesets can legitimately carry more than
-- one display string for the same system/code.
evidence_distinct AS
(
    SELECT  select_union.variable,
            select_union.subject_ref,
            select_union.code,
            MAX(CAST(select_union.display AS VARCHAR)) AS display,
            select_union.system,
            select_union.resource_ref,
            select_union.encounter_ref_link
    FROM    select_union
    GROUP BY
            select_union.variable,
            select_union.subject_ref,
            select_union.code,
            select_union.system,
            select_union.resource_ref,
            select_union.encounter_ref_link
)
SELECT  DISTINCT
        evidence_distinct.variable,
        evidence_distinct.code,
        evidence_distinct.display,
        evidence_distinct.system,
        evidence_distinct.resource_ref,
        evidence_distinct.encounter_ref_link,
        sp.subject_ref,
        sp.status,
        sp.age_at_visit,
        sp.age_group,
        sp.gender,
        sp.race_display,
        sp.ethnicity_display,
        sp.enc_period_ordinal,
        sp.enc_period_start_day,
        sp.enc_period_end_day
FROM    evidence_distinct
JOIN    pcx__cohort_study_population AS sp
ON      evidence_distinct.encounter_ref_link = sp.encounter_ref
AND     evidence_distinct.subject_ref = sp.subject_ref
;
