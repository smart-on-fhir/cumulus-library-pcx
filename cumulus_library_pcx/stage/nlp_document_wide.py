"""
NLP document wide stage: pcx__llm_document_type_wide and pcx__llm_document_topic_wide,
the document classification and topic-routing results that the clinical extraction
tasks are selected from.

Task versions come from nlp_document_tasks.workflow; see tools/nlp_wide.py.
"""
from pathlib import Path
from typing import Iterable
from cumulus_library_pcx.tools import nlp_wide
from cumulus_library_pcx.tools.nlp_wide import DEFAULT_DEPLOYMENTS
from cumulus_library_pcx.tools.manifest import Action, save_actions_toml

LABEL = 'Flatten NLP results for PCX document type and topic'
WORKFLOW = 'nlp_document_tasks.workflow'
TOML = 'nlp_document_wide.toml'

#-----------------------------------------------------------------------------
# actions
#-----------------------------------------------------------------------------
def make_actions(deployments: Iterable[str] = DEFAULT_DEPLOYMENTS) -> list[Action]:
    return nlp_wide.make_actions(WORKFLOW, LABEL, deployments)

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), TOML)

def prepare_resources(deployments: Iterable[str] = DEFAULT_DEPLOYMENTS,
                      output_dir: Path | None = None) -> list[Path]:
    """Test/inspection entry point, see nlp_wide.prepare_resources."""
    return nlp_wide.prepare_resources(WORKFLOW, LABEL, TOML, deployments, output_dir)

if __name__ == '__main__':
    print(make())
