# PCX extraction models

These models support an EHR reproduction of [ACNS0334 (PMC12833527)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/), prioritizing medulloblastoma and Group 3. They extract evidence from one document, not patient-level eligibility, randomized treatment assignment, survival duration or causal effects.

| Model module | Study purpose |
|---|---|
| `diagnosis`, `surgery`, `metastasis` | Original and revised diagnoses, age, definitive surgery, residual disease, MRI and CSF staging |
| `registry_eligibility` | `PcxTrialEligibilityAnnotation`: evidence for a separate trial-like cohort; broad discovery includes all ages |
| `molecular` | Report-level classification and assay provenance; separate MYC/MYCN and gain/amplification; preserve conflicting calls |
| `systemic_therapy`, `treatment` | Regimens, induction/consolidation, delivered versus planned doses, cycles and stem-cell infusion |
| `radiation` | Receipt, timing, field, dose and indication, including post-chemotherapy and salvage treatment |
| `response` | Baseline imaging/cytology evaluability and end-induction/end-consolidation response |
| `event`, `patient` | Dated disease events, distinct time anchors, death, last-known-alive and event-free follow-up |
| `laboratory` | Optional organ-function results and documented toxicity; prefer structured labs |
| `predisposition` | Optional documented germline findings; not required cohort eligibility |
| `medulloblastoma` | Broad any-dose discovery summary; insufficient alone for trial reproduction |
| `document_topic`, `document_type` | Routing to extraction topics and document classification |

The paper's primary response endpoint uses baseline-evaluable patients and assesses complete response after consolidation. Early progression/death must remain in that denominator. Missing response is not complete response. EFS candidates include progression/relapse, secondary malignancy and death; remission is a response state. The [registered EFS definition](https://clinicaltrials.gov/study/NCT00336024) starts at enrollment. Selecting an EHR equivalent and adjudicating events remain downstream tasks.

Routine lab names are informed by the associated trial's [eligibility listing](https://www.mayo.edu/research/clinical-trials/cls-20126460) and registry. The article does not specify the full routine lab schedule. Numeric thresholds, age calculations, staging, dose classification and cohort selection must be validated in downstream analysis; the models do not claim these derivations are implemented.

## Extraction conventions

- Retain verbatim evidence; a mention must have nonempty spans. Explicit negative tests and non-receipt are useful evidence. Silence is unknown.
- Dates with precision use ISO `YYYY-MM-DD`. Partial dates use first-of-period plus `MONTH`/`YEAR`; never treat those placeholders as exact survival dates. Exact-day-only fields in the compact discovery model keep partial dates null; detailed models preserve precision.
- Preserve distinct reports/events and disagreements for patient-level adjudication. A documented molecular group is not automatically methylation-confirmed.
- Planned doses are not actual administration. Protocol names do not establish receipt, full regimen completion or randomization.
- Actual ATRT diagnoses remain available for exclusion and retrospective reclassification. ATRT is not the required PCX diagnosis.

## Schema migration

The copied `Pnoc30*Annotation` classes are renamed `Pcx*Annotation`. `Pnoc30RegistryEligibilityAnnotation` is replaced by `PcxTrialEligibilityAnnotation` at the retained `registry_eligibility.py` path. Old payloads require explicit migration; no alias silently reinterprets registry eligibility as trial eligibility.

Other changed contracts include:

- Topic `registry_eligibility` becomes `trial_eligibility`; `response_assessment` is added.
- Molecular results become `reports` and `alterations` lists; old combined MYC/MYCN boolean fields are removed.
- `csf_cytology_14d` becomes `csf_cytology`, with collection site/date instead of an arbitrary diagnosis window.
- Patient timelines become separate anchors, vital dates and event-free follow-up records.
- Generic treatment examples are replaced by shared delivery-status and treatment-phase enums.
- New response/laboratory annotations support the broader reproduction specification.

No schema-generation entry point or in-repository callers of the old annotation classes were found during this update. External schema consumers must update imports, regenerate their JSON schemas and map payload changes before running extraction. This update does not migrate SQL, spreadsheets, stored annotations or existing extraction outputs, and does not resolve all limitations recorded in the project root.
