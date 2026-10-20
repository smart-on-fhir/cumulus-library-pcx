"""Explicit study stage order. Optional data-dependent work is opt-in."""
from cumulus_study_builder.tools.actions import Stage
from cumulus_study_builder.stage import (
    study_population,
    study_variable,
    study_variable_wide,
    casedef,
    sample,
    study_meta,
    llm_clinical_wide,
    elastic_upload,
    counts
)
from . import (
    llm_schema,
    llm_document_wide,
    eligible,
    outcome,
    client_views,
    qa_athena,
    counts_kaplan
)

STAGES = [
    Stage(study_population),
    Stage(study_variable),
    Stage(study_variable_wide),
    Stage(casedef),
    Stage(elastic_upload),
    Stage(sample),
    Stage(study_meta),
    Stage(counts), # counts.workflow (FHIR only, no LLM)
    Stage(llm_schema,
          skip_by_default=True),
    Stage('nlp_document_tasks.workflow',
          skip_by_default=True),
    Stage(llm_document_wide,
          skip_by_default=True),
    Stage('nlp_clinical_tasks.workflow',
          skip_by_default=True),
    Stage(llm_clinical_wide,
          skip_by_default=True),
    Stage(eligible,
          skip_by_default=True),
    Stage(outcome,
          skip_by_default=True),
    Stage(client_views,
          skip_by_default=True),
    Stage(qa_athena,
          skip_by_default=True),
    Stage(counts_kaplan,  # counts_kaplan.workflow (with LLM)
          skip_by_default=True),
]
