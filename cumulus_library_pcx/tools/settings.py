import os

# Named in the transition_of_care extraction prompts: set per site BEFORE generating schemas
HOME_INSTITUTION = os.environ.get("HOME_INSTITUTION", "Boston Children's Hospital (BCH)")

# Cumulus data exports go here
CUMULUS_LIBRARY_DATA_PATH = os.environ.get("CUMULUS_LIBRARY_DATA_PATH")

DATA_PACKAGE_VERSION = os.environ.get("CUMULUS_DATA_PACKAGE_VERSION", 1)

# Elastic search results go here
ELASTIC_OUTPUT_DIR = os.environ.get('ELASTIC_OUTPUT_DIR')

# NLP deployments, list of models to check if data exists
NLP_DEPLOYMENTS = ('gpt_oss_120b',)

# FHIR Encounter (only) or with date linked "encounter_ref_link"
ENCOUNTER_REF = os.environ.get("CUMULUS_ENCOUNTER_REF", "encounter_ref_link")

# CREATE VIEW AS instead of CREATE TABLE AS for patient count "cubes"
CUBE_AS_VIEW = int(os.environ.get("CUMULUS_CUBE_AS_VIEW") or 0)

# Minimum number of patients in a cumulus "cube"
CUBE_MIN_SUBJECTS = int(os.environ.get("CUMULUS_CUBE_MIN_SUBJECTS") or 10)
