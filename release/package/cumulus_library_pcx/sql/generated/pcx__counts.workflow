config_type = "counts"

[tables.cube_encounter_study_population_enc]
source_table = "(SELECT * FROM pcx__cohort_study_population_enc WHERE subject_ref IS NOT NULL AND encounter_ref IS NOT NULL)"
table_cols = [
    "age_group",
    "enc_class_display",
    "enc_period_start_year",
    "enc_servicetype_display",
    "enc_type_display",
]
description = "Patients and encounters in the study population by age group, encounter class, start year, service type and type. cnt is encounters."
secondary_id = "encounter_ref"
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_study_population]
source_table = "(SELECT * FROM pcx__cohort_study_population WHERE subject_ref IS NOT NULL)"
table_cols = [
    "age_group",
    "gender",
    "race_display",
]
description = "Patients in the study population by age group, gender and race."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_study_population_dx]
source_table = "(SELECT * FROM pcx__cohort_study_population_dx WHERE subject_ref IS NOT NULL)"
table_cols = [
    "dx_category_code",
    "dx_clinical_status",
    "dx_code",
    "dx_display",
    "dx_system",
    "dx_verification_status",
]
description = "Patients in the study population with a Condition, by category, clinical status, code and verification status."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_study_population_allergy]
source_table = "(SELECT * FROM pcx__cohort_study_population_allergy WHERE subject_ref IS NOT NULL)"
table_cols = [
    "allergy_category",
    "allergy_criticality",
    "allergy_display",
    "allergy_manifestation_display",
]
description = "Patients in the study population with an AllergyIntolerance, by category, criticality, allergen and manifestation."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_study_population_rx]
source_table = "(SELECT * FROM pcx__cohort_study_population_rx WHERE subject_ref IS NOT NULL)"
table_cols = [
    "rx_category_code",
    "rx_code",
    "rx_display",
    "rx_status",
    "rx_system",
]
description = "Patients in the study population with a MedicationRequest, by category, medication code and status."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_study_population_proc]
source_table = "(SELECT * FROM pcx__cohort_study_population_proc WHERE subject_ref IS NOT NULL)"
table_cols = [
    "proc_category_display",
    "proc_code",
    "proc_display",
    "proc_status",
    "proc_system",
]
description = "Patients in the study population with a Procedure, by category, code and status."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_study_population_lab]
source_table = "(SELECT * FROM pcx__cohort_study_population_lab WHERE subject_ref IS NOT NULL)"
table_cols = [
    "lab_observation_code",
    "lab_observation_display",
    "lab_observation_system",
    "lab_status",
]
description = "Patients in the study population with a laboratory Observation, by code and status."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_study_population_doc]
source_table = "(SELECT * FROM pcx__cohort_study_population_doc WHERE subject_ref IS NOT NULL)"
table_cols = [
    "aux_has_text",
    "doc_status",
    "doc_type_display",
]
description = "Patients in the study population with a DocumentReference, by text availability, status and type."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_documentreference_study_population_doc]
source_table = "(SELECT * FROM pcx__cohort_study_population_doc WHERE subject_ref IS NOT NULL AND documentreference_ref IS NOT NULL)"
table_cols = [
    "aux_has_text",
    "doc_status",
    "doc_type_code",
    "doc_type_display",
]
description = "Patients and DocumentReferences in the study population by text availability, status and type. cnt is documents."
secondary_id = "documentreference_ref"
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_study_population_diag]
source_table = "(SELECT * FROM pcx__cohort_study_population_diag WHERE subject_ref IS NOT NULL)"
table_cols = [
    "aux_has_text",
    "diag_category_display_best",
    "diag_code",
    "diag_display",
    "diag_system",
]
description = "Patients in the study population with a DiagnosticReport, by text availability, category and code."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_diagnosticreport_study_population_diag]
source_table = "(SELECT * FROM pcx__cohort_study_population_diag WHERE subject_ref IS NOT NULL AND diagnosticreport_ref IS NOT NULL)"
table_cols = [
    "aux_has_text",
    "diag_category_display_best",
    "diag_code",
    "diag_display",
    "diag_system",
]
description = "Patients and DiagnosticReports in the study population by text availability, category and code. cnt is reports."
secondary_id = "diagnosticreport_ref"
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_variable_union]
source_table = "(SELECT * FROM pcx__cohort_variable_union WHERE subject_ref IS NOT NULL)"
table_cols = [
    "code",
    "display",
    "system",
    "variable",
]
description = "Patients with coded study-variable evidence, by variable, code and age group at the linked encounter."
secondary_table = "pcx__cohort_study_population_enc"
secondary_cols = [
    "age_group",
]
alt_secondary_join_id = "encounter_ref_link"
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_casedef]
source_table = "(SELECT * FROM pcx__cohort_casedef WHERE subject_ref IS NOT NULL)"
table_cols = [
    "age_at_casedef_min",
    "age_group",
    "code",
    "display",
    "gender",
    "system",
]
description = "Patients in the case-definition cohort by casedef code, age at first casedef encounter, age group and gender."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_casedef_dx]
source_table = "(SELECT * FROM pcx__cohort_casedef_dx WHERE subject_ref IS NOT NULL)"
table_cols = [
    "dx_category_code",
    "dx_code",
    "dx_display",
    "dx_system",
    "variable",
]
description = "Case-definition patients with a study-variable Condition, by variable and code."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_casedef_rx]
source_table = "(SELECT * FROM pcx__cohort_casedef_rx WHERE subject_ref IS NOT NULL)"
table_cols = [
    "rx_category_code",
    "rx_code",
    "rx_display",
    "rx_status",
    "variable",
]
description = "Case-definition patients with a study-variable MedicationRequest, by variable, code and status."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_casedef_lab]
source_table = "(SELECT * FROM pcx__cohort_casedef_lab WHERE subject_ref IS NOT NULL)"
table_cols = [
    "lab_observation_code",
    "lab_observation_display",
    "lab_observation_system",
    "variable",
]
description = "Case-definition patients with a study-variable laboratory Observation, by variable and code."
primary_id = "subject_ref"
min_subject = 10

[tables.cube_patient_casedef_proc]
source_table = "(SELECT * FROM pcx__cohort_casedef_proc WHERE subject_ref IS NOT NULL)"
table_cols = [
    "proc_category_display",
    "proc_code",
    "proc_display",
    "proc_system",
    "variable",
]
description = "Case-definition patients with a study-variable Procedure, by variable and code."
primary_id = "subject_ref"
min_subject = 10
