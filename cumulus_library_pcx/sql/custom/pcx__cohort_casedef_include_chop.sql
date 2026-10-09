--    desc pcx__cohort_casedef_candidate
--
--    valueset            	'casedef_dx''
--    subtype             	{'atrt', 'cns_embryonal', 'medulloblastoma', 'pineoblastoma', 'etmr'}
--    system              	{'http://hl7.org/fhir/sid/icd-10-cm','http://snomed.info/sct', ...}
--    code                	vocabulary concept ID
--    display             	vocabulary concept display
--    tier                	1: best code match; 2: lower but still a match
--    resource_ref        	FHIR Condition/$id
--    subject_ref         	FHIR Patient/$id
--    encounter_ref_link  	FHIR Encounter/$id

CREATE  TABLE   pcx__cohort_casedef_include AS
WITH site_chop AS
(
    SELECT  DISTINCT
            -- site is chop (philadelphia)
            'SITE_CHOP'             as valueset,
            'SITE_CHOP'             as system,
            'SITE_CHOP'             as code,
            diagnosis_type_cohort   as display,
            -- subtype
            CASE diagnosis_type_cohort
                WHEN 'Medulloblastoma'                  THEN 'medulloblastoma'
                WHEN 'Atypical teratoid/rhabdoid tumor' THEN 'atrt'
                ELSE CONCAT('UNKNOWN:',diagnosis_type_cohort)
                END AS subtype,
            -- tier is always "1" highest quality match
            1   as tier,
            -- FHIR linkage
            patient_id          as subject_ref,
            enc.encounter_ref   as encounter_ref_link,
            NULL                as resource_ref
    FROM    radiant_data_dev.pcx_patient_list   as pcx_patient_list
    JOIN    pcx__cohort_study_population        as enc
    ON      pcx_patient_list.patient_id = enc.subject_ref
),
union_all AS
(
    SELECT  DISTINCT
            valueset,
            system,
            code,
            display,
            subtype,
            tier,
            subject_ref,
            encounter_ref_link,
            resource_ref
    FROM    pcx__cohort_casedef_candidate
    UNION ALL
    SELECT  * from site_chop
)
SELECT  DISTINCT
        union_all.*
FROM    union_all
WHERE   NOT EXISTS (
            SELECT  1
            FROM    pcx__cohort_casedef_exclude AS exclude
            WHERE   exclude.subject_ref = union_all.subject_ref
        )
;