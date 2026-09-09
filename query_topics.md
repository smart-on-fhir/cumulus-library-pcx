# PCX clinical-note retrieval topics

Updated 2026-09-08 using the Cumulus `rapid-elastic` skill. These are candidate
queries for human chart review, based on the PCX README and document-topic models.
Clinical terminology and retrieval performance still need domain-expert review.

[`spreadsheet/query_topics.tsv`](spreadsheet/query_topics.tsv) has two columns, `topic` and `query`. Queries use the `note`
field and Lucene query-string syntax, as sent by the local rapid-elastic adapter.
They are not Kibana KQL expressions. The definitions use explicit grouping and
retain a one-edit fuzzy medulloblastoma spelling alternative. See the
[Elasticsearch syntax reference](https://www.elastic.co/docs/reference/query-languages/query-dsl/query-dsl-query-string-query).

## Topic boundaries

| Topic                   | Candidate evidence                                                                         |
|-------------------------|--------------------------------------------------------------------------------------------|
| dx_medulloblastoma      | Named disease, morphology codes, and posterior-fossa-context historical PNET language      |
| dx_atrt                 | Named ATRT or contextual rhabdoid disease, for differential diagnosis and reclassification |
| rx_agent_methotrexate   | Methotrexate names, brands, and contextual MTX abbreviation across formulations            |
| pcx_molecular_pathology | Histology, molecular subgroup, methylation, and relevant molecular findings                |
| pcx_systemic_therapy    | Agents, protocols, treatment cycles, and stem-cell support                                 |
| pcx_radiation           | Radiation, modality, field, dose, and explicit omission or deferral                        |
| pcx_surgery             | Biopsy, resection, operative reports, and residual disease                                 |
| pcx_metastasis_staging  | Chang M stage, CSF, brain/spine dissemination, and negative staging evidence               |
| pcx_response_assessment | Measurable disease and response assessments, including negative findings                   |
| pcx_disease_event       | Progression, recurrence, remission, second malignancy, and death                           |
| pcx_patient_timeline    | Diagnosis, treatment, enrollment, vital status, and follow-up evidence                     |
| pcx_organ_function_labs | Organ-function tests, toxicity, and methotrexate monitoring/rescue                         |
| pcx_predisposition      | Germline findings, testing, uncertainty, and negative results                              |
| pcx_trial_eligibility   | ACNS0334 mentions and candidate comparability evidence                                     |

No tiers are assigned. Topic membership does not represent diagnostic certainty.
The molecular vocabulary follows the four-group framework described by
[NCI](https://www.cancer.gov/types/brain/hp/child-cns-embryonal-treatment-pdq).

Broad, ambiguous evidence topics require CNS/disease context in the same note.
Methotrexate names and selected drug/protocol terms can retrieve treatment-only
notes without a repeated diagnosis. MTX and short response abbreviations require
additional context. These rules trade some recall for fewer unrelated notes.
Follow-up notes lacking disease context can be missed. Longitudinal patient-level
note retrieval remains necessary for complete outcome ascertainment.

Negated, historical, planned, and uncertain mentions are not excluded by Boolean
NOT. They can contain essential non-receipt, negative testing, or timing evidence.
Chart review must separate patient-specific evidence from family history,
boilerplate, rule-out diagnoses, and unadministered treatment. A hit does not
establish diagnosis, receipt, high-dose therapy, trial enrollment, or eligibility.
The queries contain no age or methotrexate-exposure requirement for cohort entry.

## Naming and integration

The `dx_medulloblastoma` and `dx_atrt` names remain aligned with the corresponding
FHIR valuesets. `rx_agent_methotrexate` matches the single broad medication valueset.
The `pcx_*` topics are retrieval domains, not FHIR diagnosis variables or automatic
LLM field assignments. The existing diagnosis-comparison template unions all
Elastic topics. Non-diagnosis topics have no corresponding FHIR diagnosis match.
Filter by the intended topic family when interpreting that comparison.

The old `pnoc30_event`, `pnoc30_systemic_therapy`, `pnoc30_staging`, and
`pnoc30_registry_pathway` topics were replaced. PNOC030 consent/tissue-submission
retrieval is outside the current PCX topic set. The diagnosis queries were also
revised, so old results under those retained names are stale for these definitions.

## Validation and execution

The original query review recorded that all 14 rows passed exact-header, two-column, unique-name, quote/parenthesis, and
field-scope checks. The sibling Cumulus IEM Boolean-tree utility parsed and rendered
every query, with full token consumption and no mixed-precedence groups.
These local checks do not establish server acceptance, analyzer behavior, or
clinical sensitivity/specificity.

During the original query review, no live search, result upload, or generated-manifest/SQL changes were performed. The current main manifest still disables Elastic query and output stages; generated SQL in the repository is not evidence that a search has run.
Before running, review the terminology and use a fresh output directory or explicitly
archive existing results. rapid-elastic skips already-existing topic result files.
Exclude retired PNOC30 result CSVs when generating a new output manifest. No cached
result files were modified during this edit.

## Current repository alignment

The topic file still contains 14 distinct topics. This documentation refresh checked that inventory but did not repeat the earlier parser or server tests. Current structured population filters are ages 0–8 at visits and a minimum 365-day encounter span; these are separate from the text queries and can restrict the patient pool presented for review.

Lab retrieval is broader than numeric lab valuesets. The five folate variables and expanded AST/ALT, platelet and local creatinine definitions do not require adding every code to note-text queries. Interpret results using source documents and the [data dictionary](spreadsheet/data_dictionary.csv); topic hits alone do not populate those structured columns.
