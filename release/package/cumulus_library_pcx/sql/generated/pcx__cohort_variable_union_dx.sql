CREATE  TABLE   pcx__cohort_variable_union_dx AS
SELECT DISTINCT
        var.variable,
        var.code,
        var.display,
        var.system,
        dx.*
FROM    pcx__cohort_variable_union         AS var
JOIN    pcx__cohort_study_population_dx    AS dx
ON      var.resource_ref = dx.condition_ref

AND ((var.variable = 'dx_atrt' AND var.code = dx.dx_code AND var.system = dx.dx_system) OR (var.variable = 'dx_brain_cancer' AND var.code = dx.dx_code AND var.system = dx.dx_system) OR (var.variable = 'dx_medulloblastoma' AND var.code = dx.dx_code AND var.system = dx.dx_system) OR (var.variable = 'dx_methotrexate_toxic' AND var.code = dx.dx_code AND var.system = dx.dx_system) OR (var.variable = 'dx_radiation' AND var.code = dx.dx_code AND var.system = dx.dx_system))

AND     var.subject_ref = dx.subject_ref
AND     var.encounter_ref_link = dx.encounter_ref_link
WHERE   var.variable IN
(
 'dx_atrt'
,'dx_brain_cancer'
,'dx_medulloblastoma'
,'dx_methotrexate_toxic'
,'dx_radiation'
);
