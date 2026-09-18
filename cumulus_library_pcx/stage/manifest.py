from pathlib import Path
from cumulus_library_pcx.tools import study_builder
from cumulus_library_pcx.tools.staging import Stage
from cumulus_library_pcx.stage import (
    fhir_resource,
    study_population,
    study_variable,
    study_variable_wide,
    casedef,
    sample,
    elastic_upload,
    nlp_document_wide,
    nlp_clinical_wide,
    eligible,
    outcome,
    client_views,
    qa_athena,
    cube,
    study_meta
)

#-----------------------------------------------------------------------------
# Stages in build order: this list is the source of truth for manifest.toml
#-----------------------------------------------------------------------------
STAGES = [
    Stage(fhir_resource),
    Stage(study_population),
    Stage(study_variable),
    Stage(study_variable_wide),
    Stage(casedef),
    Stage(sample),
    Stage('elastic_query.toml', skip_by_default=True),
    Stage(elastic_upload),
    Stage('nlp_document_tasks_50k.workflow', skip_by_default=True),
    Stage('nlp_clinical_tasks_50k.workflow', skip_by_default=True),
    Stage(nlp_document_wide),
    Stage(nlp_clinical_wide),
    Stage(eligible),
    Stage(outcome),
    Stage(client_views),
    Stage(qa_athena),
    Stage(cube),
    Stage(study_meta)
]

#-----------------------------------------------------------------------------
# Make: like every stage module, manifest.py writes the toml it is named for
#-----------------------------------------------------------------------------
def make() -> Path:
    """Write manifest.toml listing every stage in STAGES, in build order."""
    return study_builder.make_manifest(STAGES)

if __name__ == '__main__':
    print('manifest:')
    print(make())
    print('===============')
    print('stages:')
    for stage in study_builder.make_stages(STAGES):
        print(stage)
