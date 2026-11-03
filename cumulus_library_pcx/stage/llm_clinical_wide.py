"""Clinical LLM wide tables, from the Claude Sonnet 5.5 results only.

The model is chosen at run time (--nlp-model claude-sonnet55), which names the result tables
pcx__nlp_<task>_claude_sonnet55. The document tasks stay on gpt-oss-120b (llm_document_wide.py).
"""
from cumulus_study_builder.tools import (
    nlp_wide,
    toml_tool
)

WORKFLOW = 'nlp_clinical_tasks.workflow'
DEPLOYMENTS = ['claude_sonnet55']

def make():
    actions = nlp_wide.make_actions(WORKFLOW, 'clinical LLM results', DEPLOYMENTS)
    return toml_tool.save_actions_toml(actions, 'llm_clinical_wide.toml')
