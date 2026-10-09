CREATE      TABLE   pcx__cohort_timeline AS
SELECT      DISTINCT
            (wide.encounter_ref_link IS NOT NULL)      AS variable_wide_bool,
            (casedef.resource_ref IS NOT NULL)          AS casedef_bool,
            (casedef.subject_ref IS NOT NULL)          AS casedef_subject_bool,
            -- casedef columns from CSV Valueset
            casedef.subtype,
            casedef.system,
            casedef.code,
            casedef.display,
            casedef.tier,
            --
            casedef.days_since                    AS casedef_days_since,
            casedef.ordinal_since                 AS casedef_ordinal_since,
            casedef.resource_ref                  AS casedef_ref,
            sp.enc_period_start_day	,
            sp.enc_period_end_day   ,
            sp.enc_period_ordinal  	,
            sp.age_at_visit        	,
            sp.gender              	,
            sp.race_display        	,
            sp.ethnicity_display   	,
            sp.encounter_ref        ,
            sp.subject_ref
FROM        pcx__cohort_study_population   AS sp
LEFT JOIN   pcx__cohort_casedef            AS casedef
ON          sp.encounter_ref = casedef.encounter_ref_link
AND         sp.subject_ref = casedef.subject_ref
LEFT JOIN   pcx__cohort_variable_wide    as wide
ON          sp.encounter_ref = wide.encounter_ref_link
;