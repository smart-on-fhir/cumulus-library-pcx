import os
from pathlib import Path

# Cumulus data exports go here
CUMULUS_LIBRARY_DATA_PATH = os.environ.get("CUMULUS_LIBRARY_DATA_PATH")

# Elastic specific data exports
ELASTIC_OUTPUT_DIR = Path(CUMULUS_LIBRARY_DATA_PATH) / 'elastic' / 'output'

# FHIR Encounter (only) or with date linekd "encounter_ref_link"
ENCOUNTER_REF = os.environ.get("CUMULUS_ENCOUNTER_REF", "encounter_ref_link")

# CREATE VIEW AS instead of CREATE TABLE AS for patient count "cubes"
CUBE_AS_VIEW = int(os.environ.get("CUMULUS_CUBE_AS_VIEW") or 0)

# Minimum number of patients in a cumulus "cube"
CUBE_MIN_SUBJECTS = int(os.environ.get("CUMULUS_CUBE_MIN_SUBJECTS") or 10)
