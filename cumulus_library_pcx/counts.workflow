# pcx shared count cubes (counts skill; replaces the former stage/cube.py and cubes.json).
# Rendered by the shared Stage(counts) into sql/generated/pcx__counts.workflow and exported.
# Every table counts distinct patients (primary_id = subject_ref, the default), and the
# builder floor min_subject = 10 applies. Encounter, document and report tables count the
# resource through secondary_id, so a cell needs 10 patients AND 10 resources; cnt is the
# resource count on those tables. Table names keep the cube_ prefix of the earlier stage.
# Workflow format: https://docs.smarthealthit.org/cumulus/library/workflows/counts.html

config_type = "counts"

[tables.cube_encounter_study_population_enc]
description = "Patients and encounters in the study population by age group, encounter class, start year, service type and type. cnt is encounters."
source_table = "{{ prefix }}__cohort_study_population_enc"
table_cols = ["age_group", "enc_class_display", "enc_period_start_year", "enc_servicetype_display", "enc_type_display"]
secondary_id = "encounter_ref"

[tables.cube_patient_study_population]
description = "Patients in the study population by age group, gender and race."
source_table = "{{ prefix }}__cohort_study_population"
table_cols = ["age_group", "gender", "race_display"]

[tables.cube_patient_study_population_dx]
description = "Patients in the study population with a Condition, by category, clinical status, code and verification status."
source_table = "{{ prefix }}__cohort_study_population_dx"
table_cols = ["dx_category_code", "dx_clinical_status", "dx_code", "dx_display", "dx_system", "dx_verification_status"]

[tables.cube_patient_study_population_allergy]
description = "Patients in the study population with an AllergyIntolerance, by category, criticality, allergen and manifestation."
source_table = "{{ prefix }}__cohort_study_population_allergy"
table_cols = ["allergy_category", "allergy_criticality", "allergy_display", "allergy_manifestation_display"]

[tables.cube_patient_study_population_rx]
description = "Patients in the study population with a MedicationRequest, by category, medication code and status."
source_table = "{{ prefix }}__cohort_study_population_rx"
table_cols = ["rx_category_code", "rx_code", "rx_display", "rx_status", "rx_system"]

[tables.cube_patient_study_population_proc]
description = "Patients in the study population with a Procedure, by category, code and status."
source_table = "{{ prefix }}__cohort_study_population_proc"
table_cols = ["proc_category_display", "proc_code", "proc_display", "proc_status", "proc_system"]

[tables.cube_patient_study_population_lab]
description = "Patients in the study population with a laboratory Observation, by code and status."
source_table = "{{ prefix }}__cohort_study_population_lab"
table_cols = ["lab_observation_code", "lab_observation_display", "lab_observation_system", "lab_status"]

[tables.cube_patient_study_population_doc]
description = "Patients in the study population with a DocumentReference, by text availability, status and type."
source_table = "{{ prefix }}__cohort_study_population_doc"
table_cols = ["aux_has_text", "doc_status", "doc_type_display"]

[tables.cube_documentreference_study_population_doc]
description = "Patients and DocumentReferences in the study population by text availability, status and type. cnt is documents."
source_table = "{{ prefix }}__cohort_study_population_doc"
table_cols = ["aux_has_text", "doc_status", "doc_type_code", "doc_type_display"]
secondary_id = "documentreference_ref"

[tables.cube_patient_study_population_diag]
description = "Patients in the study population with a DiagnosticReport, by text availability, category and code."
source_table = "{{ prefix }}__cohort_study_population_diag"
table_cols = ["aux_has_text", "diag_category_display_best", "diag_code", "diag_display", "diag_system"]

[tables.cube_diagnosticreport_study_population_diag]
description = "Patients and DiagnosticReports in the study population by text availability, category and code. cnt is reports."
source_table = "{{ prefix }}__cohort_study_population_diag"
table_cols = ["aux_has_text", "diag_category_display_best", "diag_code", "diag_display", "diag_system"]
secondary_id = "diagnosticreport_ref"

# Age group comes from the evidence's linked study-population encounter (inner join on
# encounter_ref_link), so coded evidence without a linked encounter is not counted.
[tables.cube_patient_variable_union]
description = "Patients with coded study-variable evidence, by variable, code and age group at the linked encounter."
source_table = "{{ prefix }}__cohort_variable_union"
table_cols = ["code", "display", "system", "variable"]
secondary_table = "{{ prefix }}__cohort_study_population_enc"
alt_secondary_join_id = "encounter_ref_link"
secondary_cols = ["age_group"]

# cohort_casedef already carries age group and gender from the study-population encounter.
[tables.cube_patient_casedef]
description = "Patients in the case-definition cohort by casedef code, age at first casedef encounter, age group and gender."
source_table = "{{ prefix }}__cohort_casedef"
table_cols = ["age_at_casedef_min", "age_group", "code", "display", "gender", "system"]

[tables.cube_patient_casedef_dx]
description = "Case-definition patients with a study-variable Condition, by variable and code."
source_table = "{{ prefix }}__cohort_casedef_dx"
table_cols = ["dx_category_code", "dx_code", "dx_display", "dx_system", "variable"]

[tables.cube_patient_casedef_rx]
description = "Case-definition patients with a study-variable MedicationRequest, by variable, code and status."
source_table = "{{ prefix }}__cohort_casedef_rx"
table_cols = ["rx_category_code", "rx_code", "rx_display", "rx_status", "variable"]

[tables.cube_patient_casedef_lab]
description = "Case-definition patients with a study-variable laboratory Observation, by variable and code."
source_table = "{{ prefix }}__cohort_casedef_lab"
table_cols = ["lab_observation_code", "lab_observation_display", "lab_observation_system", "variable"]

[tables.cube_patient_casedef_proc]
description = "Case-definition patients with a study-variable Procedure, by variable and code."
source_table = "{{ prefix }}__cohort_casedef_proc"
table_cols = ["proc_category_display", "proc_code", "proc_display", "proc_system", "variable"]
