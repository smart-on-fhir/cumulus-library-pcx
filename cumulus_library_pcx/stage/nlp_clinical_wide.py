"""
NLP clinical wide stage: pcx__llm_* tables for the clinical extraction tasks
(diagnosis, surgery, metastasis, molecular, systemic_therapy, radiation, response, event,
survival_timeline, laboratory, registry_eligibility, transition_of_care), one per projection.

Task versions come from nlp_clinical_tasks.workflow; see tools/nlp_wide.py.
"""
from pathlib import Path
from typing import Iterable
from cumulus_library_pcx.tools import nlp_wide
from cumulus_library_pcx.tools.nlp_wide import DEFAULT_DEPLOYMENTS
from cumulus_library_pcx.tools.actions import Action
from cumulus_library_pcx.tools.toml_tool import save_actions_toml

STAGE_TOML = 'nlp_clinical_wide.toml'
WORKFLOW = 'nlp_clinical_tasks.workflow'
LABEL = 'Flattened NLP results for Clinical Tasks'

#-----------------------------------------------------------------------------
# actions
#-----------------------------------------------------------------------------
def make_actions(deployments: Iterable[str] = DEFAULT_DEPLOYMENTS) -> list[Action]:
    return nlp_wide.make_actions(WORKFLOW, LABEL, deployments)

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), STAGE_TOML)

def make_resources(deployments: Iterable[str] = DEFAULT_DEPLOYMENTS,
                   output_dir: Path | None = None) -> list[Path]:
    """Test/inspection entry point, see nlp_wide.prepare_resources."""
    return nlp_wide.make_resources(WORKFLOW, LABEL, STAGE_TOML, deployments, output_dir)

if __name__ == '__main__':
    print(make())
