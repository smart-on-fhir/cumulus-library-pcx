CREATE  TABLE   {{ prefix }}__cohort_variable_union_rx AS
SELECT  DISTINCT
        var.variable,
        var.code,
        var.display,
        var.system,
        rx.*
FROM    {{ prefix }}__cohort_variable_union      AS var
JOIN    {{ prefix }}__cohort_study_population_rx AS rx
ON      var.resource_ref = rx.medicationrequest_ref
AND     var.system = rx.rx_system
AND     var.code = rx.rx_code
WHERE   var.variable IN
(
 {{ variable_list }}
);