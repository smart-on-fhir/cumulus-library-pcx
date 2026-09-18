from pathlib import Path
from cumulus_library_pcx.tools import template, fhir_reference
from cumulus_library_pcx.tools.actions import Action, FileAction, SqlAction
from cumulus_library_pcx.tools.toml_tool import save_actions_toml
#-----------------------------------------------------------------------------
# Upload include_*.csv files
# Common: edit the values of spreadsheet/include_*.csv
# Rare: change the UPLOAD_FILE path or contents
#-----------------------------------------------------------------------------
UPLOAD_TOML = 'file_upload_population.toml'

#-----------------------------------------------------------------------------
# Templates
#
# cohort_study_period = patient encounters specified by "include_study_period"
#
# cohort_study_population = patient encounters with additional metadata
#
# cohort_study_population_{$Reference} = see `tools.fhir_reference.Reference`
#-----------------------------------------------------------------------------
STUDY_PERIOD = 'cohort_study_period'
STUDY_POPULATION = 'cohort_study_population'
OBS_TABLES = ['cohort_study_population_obs_base', 'cohort_study_population_lab_base']

#-----------------------------------------------------------------------------
#  Actions
#-----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    """
    Study Population is built from "template/" dir.
    Study Population contains all Patient encounters matching criteria and all FHIR resources below.

    Study Builder then builds each `AspectKey`:
        dx = 'diagnoses'
        rx = 'medications'
        lab = 'labs'
        proc = 'procedures'
        doc = 'document'
        diag = 'diagnostic_report'

    Produces:
    * cohort_study_period.sql           -> Patient Encounters during study period
    * cohort_study_population.sql       -> Patient Encounters matching inclusion criteria
    * cohort_study_population_dx.sql    -> FHIR Condition
    * cohort_study_population_rx.sql    -> FHIR MedicationRequest
    * cohort_study_population_lab.sql   -> FHIR Observation.category=lab
    * cohort_study_population_doc.sql   -> FHIR DocumentReference
    * cohort_study_population_proc.sql  -> FHIR Procedure
    * cohort_study_population_diag.sql  -> FHIR DiagnosticReport

    :return: list of manifest actions, in build order
    """
    aspect_list = fhir_reference.list_aspect()
    aspect_tables = [f"{STUDY_POPULATION}_{aspect}" for aspect in aspect_list]

    return [
        FileAction(
            file_list=[f'../spreadsheet/{UPLOAD_TOML}'],
            label='inclusion criteria for study population'),
        SqlAction(
            template.copy_list(STUDY_PERIOD),
            'study_period'),
        SqlAction(
            template.copy_list(STUDY_POPULATION),
            'study_population'),
        SqlAction(
            template.copy_list(OBS_TABLES),
            'obs_base, lab_base'),
        SqlAction(
            template.copy_list(aspect_tables),
            f'study_population aspects {str(aspect_list)}'),
    ]

#-----------------------------------------------------------------------------
#  make
#-----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), 'study_population.toml')
