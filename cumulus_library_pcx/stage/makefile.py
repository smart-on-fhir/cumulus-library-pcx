from cumulus_library_pcx.tools import study_builder
from cumulus_library_pcx.tools.staging import Stage
from cumulus_library_pcx.stage import (
    study_population,
    study_variable,
    study_variable_wide,
    casedef,
    sample,
    elastic_upload,
    eligible,
    outcome,
    client_views,
    qa_athena,
    cube
)

#-----------------------------------------------------------------------------
# Stages in build order: this list is the source of truth for manifest.toml
#-----------------------------------------------------------------------------
STAGES = [
    Stage(study_population),
    Stage(study_variable),
    Stage(study_variable_wide),
    Stage(casedef),
    Stage(sample),
    Stage('elastic_query.toml', skip_by_default=True),
    Stage(elastic_upload),
    Stage('nlp_doc_type_tasks_50k.workflow', skip_by_default=True),
    Stage('nlp_clinical_tasks_50k.workflow', skip_by_default=True),
    Stage('nlp_clinical_tasks_wide.toml'),
    Stage(eligible),
    Stage(outcome),
    Stage(client_views),
    Stage(qa_athena),
    Stage(cube),
]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
if __name__ == '__main__':
    print('manifest:')
    print(study_builder.make_manifest(STAGES))
    print('===============')
    print('stages:')
    for stage in study_builder.make_stages(STAGES):
        print(stage)
