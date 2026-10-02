"""Explicit study stage order. Optional data-dependent work is opt-in."""
from cumulus_study_builder.tools.actions import Stage
from cumulus_study_builder.stage import fhir_resource, study_population, study_variable, study_variable_wide, casedef, sample, study_meta, llm_document_wide, llm_clinical_wide, elastic_upload, counts
from . import llm_schema, eligible, outcome, biostats, client_views, qa_athena

STAGES = [
    Stage(fhir_resource),
    Stage(study_population),
    Stage(study_variable),
    Stage(study_variable_wide),
    Stage(casedef),
    Stage(sample),
    Stage(llm_schema),
    Stage(elastic_upload, skip_by_default=True),
    Stage('nlp_document_tasks.workflow', skip_by_default=True),
    Stage(llm_document_wide, skip_by_default=True),
    Stage('nlp_clinical_tasks.workflow', skip_by_default=True),
    Stage(llm_clinical_wide, skip_by_default=True),
    Stage(eligible, skip_by_default=True),
    Stage(outcome, skip_by_default=True),
    # Template biostats scaffold: replace study/sql/custom/biostats/analysis.sql and
    # analysis/exports.toml with the protocol's analysis rows (PROTOCOL.md 8), then enable.
    # Stage(biostats, skip_by_default=True),
    Stage(client_views, skip_by_default=True),
    Stage('nlp_document_tasks_50k.workflow', skip_by_default=True),
    Stage('nlp_clinical_tasks_50k.workflow', skip_by_default=True),
    Stage(qa_athena, skip_by_default=True),
    Stage(counts),  # study/sql/custom/counts/counts.workflow
    Stage(study_meta),
]
