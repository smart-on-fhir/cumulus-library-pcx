# PCX extraction models

These models support an EHR reproduction of [ACNS0334 (PMC12833527)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/), prioritizing medulloblastoma and Group 3. They extract evidence from one document, not patient-level eligibility, randomized treatment assignment, survival duration or causal effects. Patient-level derivation happens in the `eligible`, `outcome` and `client_views` SQL stages ([eligible.md](docs/source/eligible.md)). Study decisions are in [PROTOCOL.md](PROTOCOL.md#5-clinical-notes); open work is in [WORKPLAN.md](WORKPLAN.md#clinical-notes).

| Model module (`cumulus_library_pcx/llm/models/`) | Task version | Study purpose |
|---|---:|---|
| `diagnosis`, `surgery`, `metastasis` | 2, 2, 2 | Original and revised diagnoses, age, definitive surgery, residual disease, MRI and CSF staging. `diagnosis` replaced the former compact `medulloblastoma` model |
| `registry_eligibility` | 1 | `TrialEligibilityAnnotation`: evidence for a separate trial-like cohort |
| `molecular` | 2 | Report-level classification and assay provenance; separate MYC/MYCN and gain/amplification; preserve conflicting calls |
| `systemic_therapy` | 1 | Regimens, induction/consolidation, delivered versus planned doses, cycles and stem-cell infusion |
| `radiation` | 2 | Receipt, timing, field, dose and indication, including post-chemotherapy and salvage treatment |
| `response` | 1 | Baseline imaging/cytology evaluability and end-induction/end-consolidation response |
| `event`, `survival_timeline` | 1, 2 | Dated disease events, distinct time anchors, death, last-known-alive and event-free follow-up |
| `laboratory` | 2 | Optional organ-function results and documented toxicity; prefer structured labs |
| `transition_of_care` | 1 | Transfer-in timing/reason, diagnosis and surgery setting, and therapy before entry |
| `document_topic`, `document_type` | 2, 2 | Routing to extraction topics and document classification |

`treatment.py` holds shared enums (`TreatmentPhase`, `DeliveryStatus`), not a task.

Task versions live in the `.workflow` files: [nlp_clinical_tasks.workflow](cumulus_library_pcx/nlp_clinical_tasks.workflow) (12 clinical tasks) and [nlp_document_tasks.workflow](cumulus_library_pcx/nlp_document_tasks.workflow) (routing and classification). Bump a task's version whenever its model changes, and regenerate the schema and the wide-table SQL together.

The paper's primary response endpoint uses baseline-evaluable patients and assesses complete response after consolidation. Early progression/death must remain in that denominator. Missing response is not complete response. EFS candidates include progression/relapse, secondary malignancy and death; remission is a response state. The [registered EFS definition](https://clinicaltrials.gov/study/NCT00336024) starts at enrollment. The outcome stage currently uses t0 (first tier 1 medulloblastoma encounter) as the EFS origin and censors at last known alive, marked provisional ([limitations.md](docs/source/limitations.md) §3–§4).

Routine lab names are informed by the associated trial's [eligibility listing](https://www.mayo.edu/research/clinical-trials/cls-20126460) and registry. The article does not specify the full routine lab schedule. Numeric thresholds, age calculations, staging, dose classification and cohort selection are validated in the SQL stages, not in the models.

## Note selection

- The document tasks (`document_topic`, `document_type`) select every note in `pcx__sample_task`, which the `sample` stage builds at every site: casedef notes plus Elasticsearch notes.
- Each clinical task selects from `pcx__llm_document_task_<task>`. No stage builds these 12 tables yet. They are declared as site-supplied in `cumulus-study.toml`, and the plan is to build them from the `document_topic` results (WORKPLAN.md, "Clinical-task selectors").
- `document_topic` has 11 routing fields for the 12 clinical tasks: `transition_of_care` has no router field.
- Nothing stops a workflow whose selection table is empty. Cumulus Library 6.3.4 then sends every note to the LLM, so check each selection has rows first.

## Extraction conventions

- Diagnosis uses evidence-backed mentions; integrated-diagnosis wording is deferred ([deferred.md](docs/source/deferred.md)), while historical diagnosis and primary-site wording remain. The shared evidence contract calls for nonempty verbatim spans for a present mention. Enforcement is warn-only by default: `base._mention_validation_issue` warns unless `CUMULUS_PCX_STRICT_MENTIONS=1`, which the test suite sets. Validators in `systemic_therapy.py`, `survival_timeline.py` and `registry_eligibility.py` still raise unconditionally, so production behaviour depends on which field is wrong (WORKPLAN.md). Explicit negative tests and non-receipt are useful evidence. Silence is unknown.
- Dates with precision use ISO `YYYY-MM-DD`. Partial dates use first-of-period plus `MONTH`/`YEAR`; never treat those placeholders as exact survival dates. The eligible and outcome SQL currently `CAST(... AS DATE)` without consulting `*_precision` (warn table `pcx__warn_llm_date_coarse`, WORKPLAN.md).
- Preserve distinct reports/events and disagreements for patient-level adjudication. A documented molecular group is not automatically methylation-confirmed.
- Planned doses are not actual administration. Protocol names do not establish receipt, full regimen completion or randomization.
- Actual ATRT diagnoses remain available for exclusion and retrospective reclassification. ATRT is not the required PCX diagnosis.
- Every `StrEnum` is KEY=VALUE. 32 of the 36 enums have a `NONE_OF_THE_ABOVE` sentinel.
- Surgery has no free-text role: the eligible SQL takes the earliest resection. Radiation `indication` is still free text, and protocol naming differs across models (`protocol_name_verbatim` in systemic therapy, `protocol_name` in the survival timeline). See WORKPLAN.md.
- Prior therapy before arrival at a site (`transition_of_care`) is distinct from prior therapy before trial-like initial treatment.

## Schema generation and wide outputs

Annotation classes use unprefixed names such as `DiagnosisAnnotation`; table names
retain the study prefix. From the repository root, generate schemas with:

```sh
export HOME_INSTITUTION="Boston Children's Hospital (BCH)"  # named in the transition_of_care prompts, set to your site
cumulus-study build llm_schema
```

`HOME_INSTITUTION` defaults to BCH when unset (`llm/models/_settings.py`). The stage writes one
schema per task module under `cumulus_library_pcx/llm/schemas/` (one `*Annotation` model per
file in `llm/models/`), plus CSV and TXT summaries under `llm/summaries/`. Both folders are
git-ignored build output. `llm_schema` is opt-in and the only stage that runs study Python.
Schema generation does not run inference. Cumulus loads the saved JSON, so editing a model's
wording changes nothing until the schemas are regenerated. Annotation models accept and
ignore unknown keys (Pydantic's default), so the schemas do not declare
`additionalProperties: false`.

The wide templates (`cumulus_library_pcx/sql/template/llm_*.sql.jinja`, 23 files) project
values without repairing dates or adjudicating evidence:

- Scalar mentions produce one row per note; lists use `UNNEST ... WITH ORDINALITY`
  and a 1-based index. Systemic therapy has separate regimen, agent, administration,
  cycle and stem-cell-infusion tables; preserve their ordinal keys when joining.
- Each table starts with `note_ref`, `encounter_ref`, `subject_ref`, `origin`,
  `generated_on`, `task_version` and `system_fingerprint`. Clinical types map to
  BIGINT, DOUBLE, BOOLEAN or VARCHAR; diagnosis dates remain VARCHAR with precision.
- Diagnosis wide output omits mention flags and evidence spans. Retrieve those from
  the source NLP result; a projected value alone is not the full evidence record.
- Two opt-in stages own the templates: `llm_clinical_wide` renders the 21 clinical
  projections of `nlp_clinical_tasks.workflow`, and `llm_document_wide` renders document type
  and topic from `nlp_document_tasks.workflow`. A template belongs to the workflow whose task
  name it starts with (`diagnosis_wide` → `diagnosis`).

`cumulus-study build` renders the SQL and the stage files. Each template is rendered once as a
`UNION ALL` over `pcx__nlp_<task>_<deployment>` for the deployments in `[builder]
nlp_deployments` of `cumulus-study.toml` (`gpt_oss_120b`), filtered to the task's `version`
from its `.workflow`. Rendering does not execute SQL or discover source tables: every source
table must exist with the expected result structure when `cumulus-library build` runs the
stage, and empty output means no usable source results, not clinical absence. Older result
structures require migration or re-extraction; filtering row versions cannot repair an
incompatible table schema.

### Tests

`tests/test_nlp_shapes.py`, `tests/test_llm_models.py` and `tests/test_llm_strict_mode.py`
cover the models, schemas, templates and strict-mention switch. DuckDB checks do not validate
Athena's nested `UNNEST` execution; the transition-of-care projection uses `array_join`,
which DuckDB lacks.
