CREATE  TABLE   {{ prefix }}__cohort_variable_union_diag AS
SELECT DISTINCT
        var.variable,
        var.code,
        var.display,
        var.system,
        diag.*
FROM    {{ prefix }}__cohort_variable_union          AS var
JOIN    {{ prefix }}__cohort_study_population_diag   AS diag
ON      var.resource_ref = diag.diagnosticreport_ref
AND     var.system = diag.diag_system
AND     var.code = diag.diag_code
WHERE   var.variable IN
(
 {{ variable_list }}
);