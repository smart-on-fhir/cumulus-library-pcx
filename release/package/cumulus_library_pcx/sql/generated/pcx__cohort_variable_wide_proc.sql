CREATE  TABLE   pcx__cohort_variable_wide_proc AS
SELECT  DISTINCT
IF(variable='proc_craniotomy', proc_performed_day, NULL) AS proc_craniotomy_date,
IF(variable='proc_craniotomy', proc_category_code, NULL) AS proc_craniotomy_code,
IF(variable='proc_craniotomy', procedure_ref, NULL) AS proc_craniotomy_ref,
IF(variable='proc_radiation', proc_performed_day, NULL) AS proc_radiation_date,
IF(variable='proc_radiation', proc_category_code, NULL) AS proc_radiation_code,
IF(variable='proc_radiation', procedure_ref, NULL) AS proc_radiation_ref,
encounter_ref_link,
subject_ref
FROM    pcx__cohort_variable_union_proc
;