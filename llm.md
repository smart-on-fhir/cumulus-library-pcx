# PCX extraction models

Checked against model, schema-generator and task configuration sources on 2026-09-10. See [chart-review output](chart_review.md) for the diagnosis version-2 projection.

These models support an EHR reproduction of [ACNS0334 (PMC12833527)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/), prioritizing medulloblastoma and Group 3. They extract evidence from one document, not patient-level eligibility, randomized treatment assignment, survival duration or causal effects.

| Model module | Study purpose |
|---|---|
| `diagnosis`, `surgery`, `metastasis` | Original and revised diagnoses, age, definitive surgery, residual disease, MRI and CSF staging |
| `registry_eligibility` | `TrialEligibilityAnnotation`: evidence for a separate trial-like cohort; the scientific discovery goal includes all ages, but current structured selection uses ages 0–8 at visits |
| `molecular` | Report-level classification and assay provenance; separate MYC/MYCN and gain/amplification; preserve conflicting calls |
| `systemic_therapy`, `treatment` | Regimens, induction/consolidation, delivered versus planned doses, cycles and stem-cell infusion |
| `radiation` | Receipt, timing, field, dose and indication, including post-chemotherapy and salvage treatment |
| `response` | Baseline imaging/cytology evaluability and end-induction/end-consolidation response |
| `event`, `patient` | Dated disease events, distinct time anchors, death, last-known-alive and event-free follow-up |
| `laboratory` | Optional organ-function results and documented toxicity; prefer structured labs |
| `predisposition` | Optional documented germline findings; not required cohort eligibility |
| `medulloblastoma` | Broad any-dose discovery summary; insufficient alone for trial reproduction |
| `transition_of_care` | Transfer-in timing/reason, diagnosis and surgery setting, and therapy before entry |
| `document_topic`, `document_type` | Routing to extraction topics and document classification |

The paper's primary response endpoint uses baseline-evaluable patients and assesses complete response after consolidation. Early progression/death must remain in that denominator. Missing response is not complete response. EFS candidates include progression/relapse, secondary malignancy and death; remission is a response state. The [registered EFS definition](https://clinicaltrials.gov/study/NCT00336024) starts at enrollment. Selecting an EHR equivalent and adjudicating events remain downstream tasks.

Routine lab names are informed by the associated trial's [eligibility listing](https://www.mayo.edu/research/clinical-trials/cls-20126460) and registry. The article does not specify the full routine lab schedule. Numeric thresholds, age calculations, staging, dose classification and cohort selection must be validated in downstream analysis; the models do not claim these derivations are implemented.

## Extraction conventions

- Diagnosis uses evidence-backed mentions; integrated-diagnosis wording is deferred, while historical diagnosis and primary-site wording remain. The shared evidence contract calls for nonempty verbatim spans for a present mention; enforcement is warn-only by default (see below). Explicit negative tests and non-receipt are useful evidence. Silence is unknown.
- Dates with precision use ISO `YYYY-MM-DD`. Partial dates use first-of-period plus `MONTH`/`YEAR`; never treat those placeholders as exact survival dates. Exact-day-only fields in the compact discovery model keep partial dates null; detailed models preserve precision.
- Preserve distinct reports/events and disagreements for patient-level adjudication. A documented molecular group is not automatically methylation-confirmed.
- Planned doses are not actual administration. Protocol names do not establish receipt, full regimen completion or randomization.
- Actual ATRT diagnoses remain available for exclusion and retrospective reclassification. ATRT is not the required PCX diagnosis.

## Schema migration

Current annotation classes have no project prefix: for example `DiagnosisAnnotation`, `PatientTimelineAnnotation` and `TrialEligibilityAnnotation`. Imports using the former `Pnoc30*Annotation` or `Pcx*Annotation` names need migration. Trial eligibility remains at `registry_eligibility.py`. Old payloads require explicit migration; no alias silently reinterprets registry eligibility as trial eligibility.

The current diagnosis configuration uses version 2 and seven mention objects.
The SQL projects ten clinical values plus seven metadata columns, without spans
or mention flags. Historical diagnosis wording is under `disease_subtype`;
`IntegratedDiagnosisMention` is deferred for later validation. See [chart_review.md](chart_review.md).

Other changed contracts include:

- Routing fields now match extraction module filenames: `response_assessment` → `response`, `molecular_pathology` → `molecular`, `disease_event` → `event`, `metastasis_staging` → `metastasis`, `organ_function_labs` → `laboratory`, `patient_timeline` → `patient`, and `trial_eligibility` → `registry_eligibility`. This changes both JSON schema properties and serialized annotation keys. Existing payloads and external selectors need explicit migration; the clinical field descriptions are unchanged. Elasticsearch retrieval labels are independent of these routing keys.
- Molecular results become `reports` and `alterations` lists; old combined MYC/MYCN boolean fields are removed.
- `csf_cytology_14d` becomes `csf_cytology`, with collection site/date instead of an arbitrary diagnosis window.
- Patient timelines become separate anchors, vital dates and event-free follow-up records.
- Generic treatment examples are replaced by shared delivery-status and treatment-phase enums.
- New response/laboratory annotations support the broader reproduction specification.

External schema consumers must use the current class names, regenerate schemas and explicitly migrate old payloads. No end-to-end inference stage is enabled in the main manifest. Model definitions and schema tests do not establish that stored annotations or external consumers have been migrated.

## Current integration and verification

The schema generator covers 14 clinical tasks plus two document tasks. `tests/test_llm_models.py` checks schema and clinical distinctions; `tests/test_llm_strict_mode.py` checks warning versus rejection behavior; `tests/test_llm_diagnosis_output.py` checks stored diagnosis artifacts and generated SQL on synthetic DuckDB records. Run `python -m pytest tests` with the project/test dependencies installed. This documentation refresh did not rerun extraction or the regression suite.

`CUMULUS_PCX_STRICT_MENTIONS` defaults to `0`. Shared span/date inconsistencies emit `MentionValidationWarning` and preserve the input, including invalid date strings. Set it to `1` before model import to raise validation errors. Other field constraints and task-specific validators still apply. The test fixture enables strict mode except where tests explicitly exercise warning mode; passing those tests does not imply production defaults reject inconsistent evidence.

The active structured stages are population, variables, wide variables, case definition and sampling. The retrieval topics in `spreadsheet/query_topics.tsv` currently select the PPV file through a symlink: four shared topics plus 14 `<module>_ppv` topics. A separate recall file provides four shared topics plus 14 `<module>_recall` topics (see [query_topics.md](query_topics.md)); topic names are retrieval labels and do not populate model fields. Neither schema existence nor note retrieval establishes patient-level survival, trial eligibility or treatment-effect estimates.

The registered [data dictionary](spreadsheet/data_dictionary.csv) uses the Cumulus column contract, but still has old medication names and lacks the toxicity columns. It does not describe the complete JSON annotation schema. Its date display types must not replace the precision-aware dates in the models. Lab CSVs now separate folate specimens and interpretation evidence; structured raw coded/text results should be consulted when the numeric wide field is null. The folate interpretation column-name conflict remains documented in [README](README.md).

## Remaining integration gaps

The document-topic model has 12 routing fields for 14 configured clinical tasks.
`medulloblastoma` and `transition_of_care` have retrieval queries but no router field;
their `select_by_table` tables are not automatically supplied by query hits. The
clinical configuration expects those selection tables to exist before extraction.

`transition_of_care.py` embeds `HOME_INSTITUTION = "Boston Children's Hospital (BCH)"`
in descriptions and generated schemas. Adapt that constant and regenerate the schema
for another site; there is currently no environment-variable setting for it. Prior
therapy before arrival at a site is distinct from prior therapy before trial-like
initial treatment.

The treatment-before-first-event flags and chemotherapy/radiation sequence in the
README still need downstream date adjudication. Surgery role and radiation indication
are free text, protocol naming differs across models, and the compact medulloblastoma
model cannot retain partial treatment dates. See the [2026-09-10 model review](reviews/llm-models-review-2026-09-10/REVIEW.md)
for proposed changes; those proposals are not implemented by this documentation update.
