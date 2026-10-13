CREATE  TABLE   pcx__cohort_variable_wide_dx AS
SELECT  DISTINCT
IF(variable='dx_atrt', dx_onset_date, NULL) AS dx_atrt_onset,
IF(variable='dx_atrt', dx_category_code, NULL) AS dx_atrt_category,
IF(variable='dx_atrt', dx_clinical_status, NULL) AS dx_atrt_status,
IF(variable='dx_atrt', condition_ref, NULL) AS dx_atrt_ref,
IF(variable='dx_brain_cancer', dx_onset_date, NULL) AS dx_brain_cancer_onset,
IF(variable='dx_brain_cancer', dx_category_code, NULL) AS dx_brain_cancer_category,
IF(variable='dx_brain_cancer', dx_clinical_status, NULL) AS dx_brain_cancer_status,
IF(variable='dx_brain_cancer', condition_ref, NULL) AS dx_brain_cancer_ref,
IF(variable='dx_medulloblastoma', dx_onset_date, NULL) AS dx_medulloblastoma_onset,
IF(variable='dx_medulloblastoma', dx_category_code, NULL) AS dx_medulloblastoma_category,
IF(variable='dx_medulloblastoma', dx_clinical_status, NULL) AS dx_medulloblastoma_status,
IF(variable='dx_medulloblastoma', condition_ref, NULL) AS dx_medulloblastoma_ref,
IF(variable='dx_methotrexate_toxic', dx_onset_date, NULL) AS dx_methotrexate_toxic_onset,
IF(variable='dx_methotrexate_toxic', dx_category_code, NULL) AS dx_methotrexate_toxic_category,
IF(variable='dx_methotrexate_toxic', dx_clinical_status, NULL) AS dx_methotrexate_toxic_status,
IF(variable='dx_methotrexate_toxic', condition_ref, NULL) AS dx_methotrexate_toxic_ref,
IF(variable='dx_radiation', dx_onset_date, NULL) AS dx_radiation_onset,
IF(variable='dx_radiation', dx_category_code, NULL) AS dx_radiation_category,
IF(variable='dx_radiation', dx_clinical_status, NULL) AS dx_radiation_status,
IF(variable='dx_radiation', condition_ref, NULL) AS dx_radiation_ref,
encounter_ref_link,
subject_ref
FROM    pcx__cohort_variable_union_dx
;