from pathlib import Path
from cumulus_library.builders.counts import CountsBuilder
from cumulus_library_pcx.tools import filetool
from cumulus_library_pcx.tools.tablespace import PREFIX, name_trim, name_cube, ctas_as_view
from cumulus_library_pcx.tools.settings import CUBE_MIN_SUBJECTS, CUBE_AS_VIEW
from cumulus_library_pcx.tools import toml_tool


def cube_fhir_resource(primary_id:str,
                       source_table='study_population',
                       table_cols=None,
                       table_name=None,
                       min_subject=CUBE_MIN_SUBJECTS) -> Path:
    """Generates a counts table using a template

    :param primary_id: The type of FHIR resource to count
    :param source_table: The table to create counts data from
    :param table_cols: The columns from the source table to add to the count table
    :param table_name: The name of the table to create. Must start with study prefix
    :param min_subject: Minimum number of patients to include in result groupings
    """
    if not table_name:
        count_type = primary_id.replace('_ref', '')
        count_type = count_type if (count_type!='subject') else 'patient'
        table_name = name_trim(source_table)
        table_name = name_cube(table_name, count_type)

    table_cols = sorted(list(set(table_cols)))
    sql = CountsBuilder(manifest=toml_tool.get_manifest()).get_count_query(
            table_name=table_name,
            source_table=source_table,
            table_cols=table_cols,
            min_subject=min_subject,
            primary_id=primary_id,
    )
    if CUBE_AS_VIEW == 1:
        sql = ctas_as_view(sql, table_name)

    return filetool.save_sql_generated(table_name, sql)

def cube_patient(source_table='study_population',
                 table_cols=None,
                 table_name=None,
                 min_subject=CUBE_MIN_SUBJECTS) -> Path:
    return cube_fhir_resource(
        primary_id='subject_ref',
        source_table=source_table,
        table_cols=table_cols,
        table_name=table_name,
        min_subject=min_subject)

def cube_encounter(source_table='study_population',
                   table_cols=None,
                   table_name=None,
                   min_subject=CUBE_MIN_SUBJECTS) -> Path:
    return cube_fhir_resource(
        primary_id='encounter_ref',
        source_table=source_table,
        table_cols=table_cols,
        table_name=table_name,
        min_subject=min_subject)

def cube_document(source_table='study_population_doc',
                  table_cols=None,
                  table_name=None,
                  min_subject=CUBE_MIN_SUBJECTS) -> Path:
    return cube_fhir_resource(
        primary_id='documentreference_ref',
        source_table=source_table,
        table_cols=table_cols,
        table_name=table_name,
        min_subject=min_subject)

def cube_diagnostic(source_table='study_population_doc',
                    table_cols=None,
                    table_name=None,
                    min_subject=CUBE_MIN_SUBJECTS) -> Path:
    return cube_fhir_resource(
        primary_id='diagnosticreport_ref',
        source_table=source_table,
        table_cols=table_cols,
        table_name=table_name,
        min_subject=min_subject)

def cube_note(source_table='sample_casedef',
              table_cols=None,
              table_name=None,
              min_subject=CUBE_MIN_SUBJECTS) -> Path:
    return cube_fhir_resource(
        primary_id='note_ref',
        source_table=source_table,
        table_cols=table_cols,
        table_name=table_name,
        min_subject=min_subject)


###############################################################################
# PCX cube tables: one make_* per stage whose tables are counted.
# Each returns the custom SQL it wrote, in build order.
###############################################################################
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
