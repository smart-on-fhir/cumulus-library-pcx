CREATE  TABLE   {{ prefix }}__cohort_variable_union_enc AS
SELECT  DISTINCT
        var.variable,
        var.code,
        var.display,
        var.system,
        enc.*
FROM    {{ prefix }}__cohort_variable_union          AS var
JOIN    {{ prefix }}__cohort_study_population_enc    AS enc
ON      var.resource_ref = enc.encounter_ref
WHERE   var.variable IN
(
 {{ variable_list }}
);
;