from pathlib import Path
from cumulus_library_pcx.tools import manifest, template

# -----------------------------------------------------------------------------
# FHIR resource tables that extend the cumulus CORE layer.
#
# One table per resource, named prefix__<resource>, rendered from
# template/<resource>.sql into athena/. Built as the first stage so every
# later stage (study_population onward) can join them.
#
#   medicationrequest  -> core__medicationrequest columns plus course of therapy,
#                         status reason, prior prescription, dosage, dispense
#                         request, and the days-supply coverage interval
#   medicationdispense -> the fill: hand-over date, days supply, quantity,
#                         first-fill vs refill, category, authorizing request,
#                         and the coverage interval the fill implies

#-----------------------------------------------------------------------------
# Templates
#-----------------------------------------------------------------------------
MEDICATION_REQUEST = [
    'medicationrequest'
]
MEDICATION_DISPENSE = [
    'medicationdispense_dn_inline_code',
    'medicationdispense_dn_contained_code',
    'medicationdispense',
]

def make_template(resource_list: list[str]) -> list[Path]:
    """
    :param resource_list: FHIR resource names in lowercase
    :return: list of rendered athena/prefix__<resource>.sql paths
    """
    return [template.copy(f"{resource}.sql")
            for resource in resource_list]

#-----------------------------------------------------------------------------
# Actions
#-----------------------------------------------------------------------------
def make_actions() -> list[manifest.Action]:
    return [manifest.SqlAction(make_template(MEDICATION_REQUEST),
                               'FHIR MedicationRequest'),
            manifest.SqlAction(make_template(MEDICATION_DISPENSE),
                               'FHIR MedicationDispense')]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return manifest.save_actions_toml(make_actions(), 'fhir_resource.toml')

if __name__ == '__main__':
    make()
