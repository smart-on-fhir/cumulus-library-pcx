CREATE  TABLE   pcx__cohort_variable_union_rx AS
SELECT  DISTINCT
        var.variable,
        var.code,
        var.display,
        var.system,
        rx.*
FROM    pcx__cohort_variable_union      AS var
JOIN    pcx__cohort_study_population_rx AS rx
ON      var.resource_ref = rx.medicationrequest_ref

AND ((var.variable = 'rx_chemo_carboplatin' AND var.code = rx.rx_code AND var.system = rx.rx_system) OR (var.variable = 'rx_chemo_cisplatin' AND var.code = rx.rx_code AND var.system = rx.rx_system) OR (var.variable = 'rx_chemo_cyclophosphamide' AND var.code = rx.rx_code AND var.system = rx.rx_system) OR (var.variable = 'rx_chemo_etoposide' AND var.code = rx.rx_code AND var.system = rx.rx_system) OR (var.variable = 'rx_chemo_thiotepa' AND var.code = rx.rx_code AND var.system = rx.rx_system) OR (var.variable = 'rx_chemo_vincristine' AND var.code = rx.rx_code AND var.system = rx.rx_system) OR (var.variable = 'rx_contrast_methotrexate' AND var.code = rx.rx_code AND var.system = rx.rx_system))

AND     var.subject_ref = rx.subject_ref
AND     var.encounter_ref_link = rx.encounter_ref_link
WHERE   var.variable IN
(
 'rx_chemo_carboplatin'
,'rx_chemo_cisplatin'
,'rx_chemo_cyclophosphamide'
,'rx_chemo_etoposide'
,'rx_chemo_thiotepa'
,'rx_chemo_vincristine'
,'rx_contrast_methotrexate'
);
