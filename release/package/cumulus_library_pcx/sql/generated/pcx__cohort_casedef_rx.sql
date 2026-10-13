CREATE  TABLE   pcx__cohort_casedef_rx AS
WITH periods AS (
    SELECT DISTINCT subject_ref, encounter_ref_link, days_since, ordinal_since, casedef_period
    FROM pcx__cohort_casedef
)
SELECT  DISTINCT
        periods.days_since,
        periods.ordinal_since,
        periods.casedef_period,
        variable_union.variable,
        -- casedef columns from CSV Valueset
        casedef.subtype,
        casedef.system,
        casedef.code,
        casedef.display,
        casedef.tier,
        --
        rx.*
FROM    periods
JOIN    pcx__cohort_study_population_rx    AS rx
ON      periods.encounter_ref_link = rx.encounter_ref_link
AND     periods.subject_ref = rx.subject_ref
LEFT JOIN pcx__cohort_casedef AS casedef
ON      casedef.resource_ref = rx.medicationrequest_ref
AND     casedef.subject_ref = rx.subject_ref
AND     casedef.encounter_ref_link = rx.encounter_ref_link
LEFT JOIN pcx__cohort_variable_union       AS variable_union
ON      rx.medicationrequest_ref = variable_union.resource_ref
AND     rx.subject_ref = variable_union.subject_ref
AND     rx.encounter_ref_link = variable_union.encounter_ref_link
;