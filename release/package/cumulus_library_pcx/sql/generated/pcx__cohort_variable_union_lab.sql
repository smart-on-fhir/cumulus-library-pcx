CREATE  TABLE   pcx__cohort_variable_union_lab AS
SELECT  DISTINCT
        var.variable,
        var.code,
        var.display,
        var.system,
        lab.*
FROM    pcx__cohort_variable_union          AS var
JOIN    pcx__cohort_study_population_lab    AS lab
ON      var.resource_ref = lab.observation_ref

AND ((var.variable = 'lab_absolute_neutrophil_count' AND var.code = lab.lab_observation_code AND var.system = lab.lab_observation_system) OR (var.variable = 'lab_alt' AND var.code = lab.lab_observation_code AND var.system = lab.lab_observation_system) OR (var.variable = 'lab_ast' AND var.code = lab.lab_observation_code AND var.system = lab.lab_observation_system) OR (var.variable = 'lab_creatinine' AND var.code = lab.lab_observation_code AND var.system = lab.lab_observation_system) OR (var.variable = 'lab_hemoglobin' AND var.code = lab.lab_observation_code AND var.system = lab.lab_observation_system) OR (var.variable = 'lab_platelets' AND var.code = lab.lab_observation_code AND var.system = lab.lab_observation_system) OR (var.variable = 'lab_total_bilirubin' AND var.code = lab.lab_observation_code AND var.system = lab.lab_observation_system))

AND     var.subject_ref = lab.subject_ref
AND     var.encounter_ref_link = lab.encounter_ref_link
WHERE   var.variable IN
(
 'lab_absolute_neutrophil_count'
,'lab_alt'
,'lab_ast'
,'lab_creatinine'
,'lab_hemoglobin'
,'lab_platelets'
,'lab_total_bilirubin'
);
