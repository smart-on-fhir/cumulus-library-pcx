"""Document LLM wide tables, then the per-task note selectors that read them."""
from cumulus_study_builder.tools import nlp_wide, sql_stage, toml_tool
from cumulus_study_builder.tools.actions import SqlAction

WORKFLOW = 'nlp_document_tasks.workflow'
DEPLOYMENTS = ['gpt_oss_120b']   # the document tasks run on gpt-oss-120b, the clinical tasks on Claude Sonnet 5.5
TASK_FILES = ['pcx__llm_document_task.sql']


def make():
    actions = nlp_wide.make_actions(WORKFLOW, 'document LLM results', DEPLOYMENTS)
    task_sql = list()
    for filename in TASK_FILES:
        task_sql.append(sql_stage.study_sql(filename))
    actions.append(SqlAction(task_sql, 'document LLM task views'))
    return toml_tool.save_actions_toml(actions, 'llm_document_wide.toml')