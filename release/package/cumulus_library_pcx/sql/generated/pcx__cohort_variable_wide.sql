CREATE  TABLE   pcx__cohort_variable_wide AS
with
select_wide_bool AS
(
    SELECT
            CASE WHEN variable = 'dx_atrt' THEN TRUE ELSE FALSE END AS dx_atrt,
CASE WHEN variable = 'dx_brain_cancer' THEN TRUE ELSE FALSE END AS dx_brain_cancer,
CASE WHEN variable = 'dx_medulloblastoma' THEN TRUE ELSE FALSE END AS dx_medulloblastoma,
CASE WHEN variable = 'dx_methotrexate_toxic' THEN TRUE ELSE FALSE END AS dx_methotrexate_toxic,
CASE WHEN variable = 'dx_radiation' THEN TRUE ELSE FALSE END AS dx_radiation,
CASE WHEN variable = 'lab_absolute_neutrophil_count' THEN TRUE ELSE FALSE END AS lab_absolute_neutrophil_count,
CASE WHEN variable = 'lab_alt' THEN TRUE ELSE FALSE END AS lab_alt,
CASE WHEN variable = 'lab_ast' THEN TRUE ELSE FALSE END AS lab_ast,
CASE WHEN variable = 'lab_creatinine' THEN TRUE ELSE FALSE END AS lab_creatinine,
CASE WHEN variable = 'lab_hemoglobin' THEN TRUE ELSE FALSE END AS lab_hemoglobin,
CASE WHEN variable = 'lab_platelets' THEN TRUE ELSE FALSE END AS lab_platelets,
CASE WHEN variable = 'lab_total_bilirubin' THEN TRUE ELSE FALSE END AS lab_total_bilirubin,
CASE WHEN variable = 'proc_craniotomy' THEN TRUE ELSE FALSE END AS proc_craniotomy,
CASE WHEN variable = 'proc_radiation' THEN TRUE ELSE FALSE END AS proc_radiation,
CASE WHEN variable = 'rx_chemo_carboplatin' THEN TRUE ELSE FALSE END AS rx_chemo_carboplatin,
CASE WHEN variable = 'rx_chemo_cisplatin' THEN TRUE ELSE FALSE END AS rx_chemo_cisplatin,
CASE WHEN variable = 'rx_chemo_cyclophosphamide' THEN TRUE ELSE FALSE END AS rx_chemo_cyclophosphamide,
CASE WHEN variable = 'rx_chemo_etoposide' THEN TRUE ELSE FALSE END AS rx_chemo_etoposide,
CASE WHEN variable = 'rx_chemo_thiotepa' THEN TRUE ELSE FALSE END AS rx_chemo_thiotepa,
CASE WHEN variable = 'rx_chemo_vincristine' THEN TRUE ELSE FALSE END AS rx_chemo_vincristine,
CASE WHEN variable = 'rx_contrast_methotrexate' THEN TRUE ELSE FALSE END AS rx_contrast_methotrexate,
            encounter_ref_link
    FROM    pcx__cohort_variable_union
),
select_wide_any AS
(
    SELECT
            BOOL_OR(dx_atrt) AS dx_atrt,
BOOL_OR(dx_brain_cancer) AS dx_brain_cancer,
BOOL_OR(dx_medulloblastoma) AS dx_medulloblastoma,
BOOL_OR(dx_methotrexate_toxic) AS dx_methotrexate_toxic,
BOOL_OR(dx_radiation) AS dx_radiation,
BOOL_OR(lab_absolute_neutrophil_count) AS lab_absolute_neutrophil_count,
BOOL_OR(lab_alt) AS lab_alt,
BOOL_OR(lab_ast) AS lab_ast,
BOOL_OR(lab_creatinine) AS lab_creatinine,
BOOL_OR(lab_hemoglobin) AS lab_hemoglobin,
BOOL_OR(lab_platelets) AS lab_platelets,
BOOL_OR(lab_total_bilirubin) AS lab_total_bilirubin,
BOOL_OR(proc_craniotomy) AS proc_craniotomy,
BOOL_OR(proc_radiation) AS proc_radiation,
BOOL_OR(rx_chemo_carboplatin) AS rx_chemo_carboplatin,
BOOL_OR(rx_chemo_cisplatin) AS rx_chemo_cisplatin,
BOOL_OR(rx_chemo_cyclophosphamide) AS rx_chemo_cyclophosphamide,
BOOL_OR(rx_chemo_etoposide) AS rx_chemo_etoposide,
BOOL_OR(rx_chemo_thiotepa) AS rx_chemo_thiotepa,
BOOL_OR(rx_chemo_vincristine) AS rx_chemo_vincristine,
BOOL_OR(rx_contrast_methotrexate) AS rx_contrast_methotrexate,
            encounter_ref_link
    FROM    select_wide_bool
    GROUP BY encounter_ref_link
)
SELECT  DISTINCT
        select_wide_any.*
FROM    select_wide_any
;