from pathlib import Path
from cumulus_library_pcx.tools.manifest import (
    Action,
    ExportAction,
    SqlAction,
    save_actions_toml
)
from cumulus_library_pcx.tools.cube_helper import PREFIX
from cumulus_library_pcx.tools.cube_helper import (
    cube_patient,
    cube_encounter,
    cube_note,
    cube_document,
    cube_diagnostic
)


#-----------------------------------------------------------------------------
# Study Population
#-----------------------------------------------------------------------------
def make_study_population() -> list[Path]:
    return [
        # encounters for study population
        cube_encounter(source_table=f'{PREFIX}__cohort_study_population_enc',
                       table_cols=['age_group',
                                   'age_at_visit',
                                   'enc_period_start_year',
                                   'enc_class_display',
                                   'enc_type_display',
                                   'enc_servicetype_display']),

        # patients for study population
        cube_patient(source_table=f'{PREFIX}__cohort_study_population',
                     table_cols=['age_group',
                                 'gender',
                                 'race_display']),

        # Diagnosis
        cube_patient(source_table=f'{PREFIX}__cohort_study_population_dx',
                     table_cols=['dx_clinical_status',
                                 'dx_verification_status',
                                 'dx_category_code',
                                 'dx_system',
                                 'dx_code',
                                 'dx_display']),

        # Allergy
        cube_patient(source_table=f'{PREFIX}__cohort_study_population_allergy',
                     table_cols=['allergy_category',
                                 'allergy_criticality',
                                 'allergy_display',
                                 'allergy_manifestation_display']),

        # Medications
        cube_patient(source_table=f'{PREFIX}__cohort_study_population_rx',
                     table_cols=['rx_status',
                                 'rx_category_code',
                                 'rx_system',
                                 'rx_code',
                                 'rx_display']),

        # Procedures
        cube_patient(source_table=f'{PREFIX}__cohort_study_population_proc',
                     table_cols=['proc_status',
                                 'proc_category_display',
                                 'proc_system',
                                 'proc_code',
                                 'proc_display']),

        # Lab Observations
        cube_patient(source_table=f'{PREFIX}__cohort_study_population_lab',
                     table_cols=['lab_status',
                                 'lab_observation_system',
                                 'lab_observation_code',
                                 'lab_observation_display']),

        # Documents
        cube_patient(source_table=f'{PREFIX}__cohort_study_population_doc',
                     table_cols=['doc_status',
                                 'doc_type_display',
                                 'aux_has_text']),

        cube_document(source_table=f'{PREFIX}__cohort_study_population_doc',
                      table_cols=['doc_status',
                                  'doc_type_code',
                                  'doc_type_display',
                                  'aux_has_text']),

        # Diagnostic Reports
        cube_patient(source_table=f'{PREFIX}__cohort_study_population_diag',
                     table_cols=['diag_category_display_best',
                                 'diag_system',
                                 'diag_code',
                                 'diag_display',
                                 'aux_has_text']),

        cube_diagnostic(source_table=f'{PREFIX}__cohort_study_population_diag',
                        table_cols=['diag_category_display_best',
                                    'diag_system',
                                    'diag_code',
                                    'diag_display',
                                    'aux_has_text']),
    ]

#-----------------------------------------------------------------------------
# Case Definition
#-----------------------------------------------------------------------------
def make_casedef() -> list[Path]:
    return [
        # Count patients for casedef
        cube_patient(source_table=f'{PREFIX}__cohort_casedef',
                     table_cols=['age_at_casedef_min',
                                 'age_group',
                                 'gender',
                                 'system',
                                 'code',
                                 'display']),

        # DX Diagnoses
        cube_patient(source_table=f'{PREFIX}__cohort_casedef_dx',
                     table_cols=['variable',
                                 'dx_category_code',
                                 'dx_code',
                                 'dx_system',
                                 'dx_display']),

        # RX Medications
        cube_patient(source_table=f'{PREFIX}__cohort_casedef_rx',
                     table_cols=['variable',
                                 'rx_category_code',
                                 'rx_status',
                                 'rx_code',
                                 'rx_display']),

        # Lab Observations
        cube_patient(source_table=f'{PREFIX}__cohort_casedef_lab',
                     table_cols=['variable',
                                 'lab_observation_system',
                                 'lab_observation_code',
                                 'lab_observation_display']),

        # Procedures
        cube_patient(source_table=f'{PREFIX}__cohort_casedef_proc',
                     table_cols=['variable',
                                 'proc_category_display',
                                 'proc_system',
                                 'proc_code',
                                 'proc_display']),
    ]

#-----------------------------------------------------------------------------
# Samples from Case Definition
#-----------------------------------------------------------------------------
def make_casedef_samples() -> list[Path]:
    table_cols = ['fhir_resource',
                  'note_code',
                  'note_display',
                  'note_system']

    sample_casedef = f'{PREFIX}__sample_casedef'
    temporality = ['pre', 'peri', 'peri_post', 'post']

    source_table_list = [sample_casedef]
    source_table_list+= [f'{sample_casedef}_{t}' for t in temporality]

    target_output = [cube_patient(source_table, table_cols) for source_table in source_table_list]
    target_output+= [cube_note(source_table, table_cols) for source_table in source_table_list]

    return target_output

#-----------------------------------------------------------------------------
# Variables (coded vars matching FHIR resource)
#-----------------------------------------------------------------------------
def make_variable_union() -> list[Path]:
    return [
        cube_patient(source_table=f'{PREFIX}__cohort_variable_union',
                     table_cols=['age_group',
                                 'variable',
                                 'code',
                                 'system',
                                 'display'])]

#-----------------------------------------------------------------------------
# actions
#-----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    population_sql_list = make_study_population()
    casedef_sql_list = make_casedef()
    sample_sql_list = make_casedef_samples()
    variable_sql_list = make_variable_union()

    return [SqlAction(population_sql_list, 'SQL cube study population'),
            ExportAction(population_sql_list, 'export cube tables study populations'),

            SqlAction(variable_sql_list, 'SQL cube variable union'),
            ExportAction(variable_sql_list, 'export cube tables variable union'),

            SqlAction(casedef_sql_list, 'SQL cube casedef'),
            ExportAction(casedef_sql_list, 'export cube tables casedef'),

            SqlAction(sample_sql_list, 'SQL cube casedef sample'),
            ExportAction(sample_sql_list, 'export cube tables casedef sample'),
    ]

#-----------------------------------------------------------------------------
# make
#-----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), 'cube.toml')

if __name__ == "__main__":
    make()
