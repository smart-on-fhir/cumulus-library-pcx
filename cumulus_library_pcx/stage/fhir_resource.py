from pathlib import Path
from cumulus_library_pcx.tools import toml_tool, template
from cumulus_library_pcx.tools.actions import Action, SqlAction

# -----------------------------------------------------------------------------
# FHIR resource tables that extend the cumulus CORE layer.
#
# One table per resource, named prefix__<resource>, rendered from
# template/<resource>.sql into custom/. Built as the first stage so every
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

#-----------------------------------------------------------------------------
# Actions
#-----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    return [SqlAction(template.save_list(MEDICATION_REQUEST),
                      'FHIR MedicationRequest'),
            SqlAction(template.save_list(MEDICATION_DISPENSE),
                      'FHIR MedicationDispense')]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return toml_tool.save_actions_toml(make_actions(), 'fhir_resource.toml')
