CREATE  TABLE   {{ prefix }}__cohort_variable_union_lab AS
SELECT  DISTINCT
        var.variable,
        var.code,
        var.display,
        var.system,
        lab.*
FROM    {{ prefix }}__cohort_variable_union          AS var
JOIN    {{ prefix }}__cohort_study_population_lab    AS lab
ON      var.resource_ref = lab.observation_ref
AND     var.system = lab.lab_observation_system
AND     var.code = lab.lab_observation_code
WHERE   var.variable IN
(
 {{ variable_list }}
);
