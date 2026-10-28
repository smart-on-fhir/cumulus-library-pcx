--    desc pcx__cohort_casedef_candidate
--
--    valueset            	'casedef_dx''
--    subtype             	{'atrt', 'cns_embryonal', 'medulloblastoma', 'pineoblastoma', 'etmr'}
--    system              	{'http://hl7.org/fhir/sid/icd-10-cm','http://snomed.info/sct', ...}
--    code                	vocabulary concept ID
--    display             	vocabulary concept display
--    tier                	tier=1: t0 set to first match, tier=2: t0 extracted by LLM
--    resource_ref        	FHIR Condition/$id
--    subject_ref         	FHIR Patient/$id
--    encounter_ref_link  	FHIR Encounter/$id

CREATE  TABLE   pcx__cohort_casedef_include AS
SELECT  DISTINCT
        -- site is chop (philadelphia)
        'SITE_CHOP'             as valueset,
        'SITE_CHOP'             as system,
        'SITE_CHOP'             as code,
        diagnosis_type_cohort   as display,
        -- tier 2: PCX subject specified without diagnosis date (OK).
        -- LLM extracted diagnosis date will serve as time=0 (t0).
        2   as tier,
        -- subtype
        CASE diagnosis_type_cohort
            WHEN 'Medulloblastoma'                  THEN 'medulloblastoma'
            WHEN 'Atypical teratoid/rhabdoid tumor' THEN 'atrt'
            ELSE CONCAT('UNKNOWN:',diagnosis_type_cohort)
            END AS subtype,
        -- FHIR linkage
        enc.subject_ref     as subject_ref,
        enc.encounter_ref   as encounter_ref_link,
        NULL                as resource_ref
FROM    radiant_data_dev.pcx_patient_list   as pcx_patient_list
JOIN    pcx__cohort_study_population        as enc
ON      CONCAT('Patient/', pcx_patient_list.anon_id) = enc.subject_ref
;