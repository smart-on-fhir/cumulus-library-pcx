CREATE  TABLE   pcx__cohort_variable_union_proc AS
SELECT  DISTINCT
        var.variable,
        var.code,
        var.display,
        var.system,
        proc.*
FROM    pcx__cohort_variable_union         AS var
JOIN    pcx__cohort_study_population_proc  AS proc
ON      var.resource_ref = proc.procedure_ref

AND ((var.variable = 'proc_craniotomy' AND var.code = proc.proc_code AND var.system = proc.proc_system) OR (var.variable = 'proc_radiation' AND var.code = proc.proc_code AND var.system = proc.proc_system))

AND     var.subject_ref = proc.subject_ref
AND     var.encounter_ref_link = proc.encounter_ref_link
WHERE   var.variable IN
(
 'proc_craniotomy'
,'proc_radiation'
);
