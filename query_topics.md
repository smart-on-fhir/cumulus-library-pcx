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
| dx_medulloblastoma      | Named disease with wildcards, ICD-O morphology codes 9470–9477/3, and posterior-fossa-context historical PNET language; the MB patient-level join key |
| dx_atrt                 | Named ATRT, 9508/3, or rhabdoid with CNS/INI1/SMARCB1/SMARCA4/BRG1 context, for exclusion and reclassification |
| rx_agent_methotrexate   | Methotrexate names, brands, and contextual MTX abbreviation across formulations            |
| transition_of_care_recall | General patient-transfer language: transfer of care, outside hospital/records/provider, referred from, previously treated at, establish care, second opinion, transport (transition_of_care.py) |
| transition_of_care_ppv  | Brain-tumor-specific transfer settings: transferred/referred for neurosurgery, proton, stem-cell rescue or protocol; resected or induction started at an outside hospital; outside pathology or slides reviewed here; outside CT/MRI showing a posterior fossa mass; treatment-naive or newly diagnosed on arrival; or an outside-institution term with a tumor/surgery/oncology term in the same note (transition_of_care.py) |
| rx_chemotherapy         | Backbone agents of ACNS0334 induction/consolidation (vincristine, carboplatin, cyclophosphamide, cisplatin, thiotepa, etoposide): generic and brand names, with context-gated abbreviations; methotrexate is a separate topic |
| diagnosis_recall        | dx_medulloblastoma OR dx_atrt OR every other CNS tumor family in CnsDiagnosisCategory (ETMR, pineoblastoma, sPNET, embryonal NOS, glioma, ependymoma, craniopharyngioma, choroid plexus, germ cell, glioneuronal, CNS sarcoma) and generic brain-tumor terms; both dx_* rows are verbatim branches (diagnosis.py) |
| diagnosis_ppv           | A named tumor entity or ICD-O code AND diagnosis-establishing language (final/integrated/pathologic diagnosis, patholog*, histolog*, biops*, resect*, WHO grade, consistent with, histology pattern, M-stage, primary site) in the same note (diagnosis.py) |
| surgery_recall          | Tumor surgery, extent of resection, residual disease, second-look and dates (surgery.py); single words and abbreviations |
| surgery_ppv             | Tumor surgery, extent of resection, residual disease, second-look and dates (surgery.py); multi-word phrases written when the fact is documented |
| metastasis_recall       | Chang staging inputs: CSF cytology, brain/spine MRI, extraneural disease, metastatic sites (metastasis.py); single words and abbreviations |
| metastasis_ppv          | Chang staging inputs: CSF cytology, brain/spine MRI, extraneural disease, metastatic sites (metastasis.py); multi-word phrases written when the fact is documented |
| molecular_recall        | Molecular group, methylation class, assay provenance, MYC/MYCN and chromosomal alterations (molecular.py); single words and abbreviations |
| molecular_ppv           | Molecular group, methylation class, assay provenance, MYC/MYCN and chromosomal alterations (molecular.py); multi-word phrases written when the fact is documented |
| systemic_therapy_recall | Regimens, agents, cycles, doses, delivery status, stem-cell infusion (systemic_therapy.py); single words and abbreviations |
| systemic_therapy_ppv    | Regimens, agents, cycles, doses, delivery status, stem-cell infusion (systemic_therapy.py); multi-word phrases written when the fact is documented |
| radiation_recall        | Radiation delivery/plan, field, dose, timing and explicit omission (radiation.py); single words and abbreviations |
| radiation_ppv           | Radiation delivery/plan, field, dose, timing and explicit omission (radiation.py); multi-word phrases written when the fact is documented |
| response_recall         | Baseline evaluability and CR/PR/SD/PD assessments by treatment timepoint (response.py); single words and abbreviations |
| response_ppv            | Baseline evaluability and CR/PR/SD/PD assessments by treatment timepoint (response.py); multi-word phrases written when the fact is documented |
| event_recall            | Dated progression, recurrence, remission, second malignancy and death (event.py); single words and abbreviations |
| event_ppv               | Dated progression, recurrence, remission, second malignancy and death (event.py); multi-word phrases written when the fact is documented |
| patient_recall          | Timeline anchors, vital status, last-known-alive and event-free follow-up (patient.py); single words and abbreviations |
| patient_ppv             | Timeline anchors, vital status, last-known-alive and event-free follow-up (patient.py); multi-word phrases written when the fact is documented |
| laboratory_recall       | Organ-function results, MTX levels/clearance and documented toxicity (laboratory.py); single words and abbreviations |
| laboratory_ppv          | Organ-function results, MTX levels/clearance and documented toxicity (laboratory.py); multi-word phrases written when the fact is documented |
| predisposition_recall   | Germline findings, testing, VUS and negative results (predisposition.py); single words and abbreviations |
| predisposition_ppv      | Germline findings, testing, VUS and negative results (predisposition.py); multi-word phrases written when the fact is documented |
| registry_eligibility_recall | ACNS0334 comparability criteria: age at surgery, newly diagnosed high-risk disease, prior therapy, organ function (registry_eligibility.py); single words and abbreviations |
| registry_eligibility_ppv | ACNS0334 comparability criteria: age at surgery, newly diagnosed high-risk disease, prior therapy, organ function (registry_eligibility.py); multi-word phrases written when the fact is documented |
| medulloblastoma_recall  | Compact any-dose discovery summary: MTX, radiation, group, survival in one pass (medulloblastoma.py); single words and abbreviations |
| medulloblastoma_ppv     | Compact any-dose discovery summary: MTX, radiation, group, survival in one pass (medulloblastoma.py); multi-word phrases written when the fact is documented |

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

## Task-named queries (recall versus PPV)

Added 2026-09-09; revised the same day for intersection use, then merged with a second
independently written set (best-of-breed: wildcard stems and AND-structured PPV clauses from the
second set; gated abbreviations, phrase lists, brand names and negative-evidence phrases from the first). Each LLM extraction module in
`cumulus_library_pcx/llm/models/` has queries named for the module file so routing is
mechanical. Where a broad and a narrow form differ they are suffixed `_recall` and `_ppv`;
where one query serves both purposes the bare module name is used (`document_topic`,
`document_type`). `base.py` and `treatment.py` define shared classes and enums, not
extraction tasks, and have no query.

**Intersection design.** These queries are meant to be joined at the patient level:
`diagnosis_recall` (or the structured case definition) establishes that a patient is a
medulloblastoma/embryonal case, and each task query is then intersected with that patient
set. Task queries therefore match on task evidence alone and do not require the tumor to be
named in the same note. A radiation-oncology summary, a lab-toxicity note or an outside-records
review often never says "medulloblastoma"; requiring it would silently drop those notes.
Run alone, without the join, the task queries will return notes from unrelated patients.
Only `diagnosis_recall`, `diagnosis_ppv`, `dx_*` and
the older `pcx_*` rows carry disease terms.

The recall/PPV split is a single lever, term specificity:

| Form | Terms | Intended use |
|---|---|---|
| `_recall` | Single words and abbreviations (resection, cytology, progression, Gy, germline), abbreviations gated by a companion term | Maximize the candidate note set; accept many notes where the model returns nothing |
| `_ppv` | Multi-word phrases a clinician writes when the fact is actually documented ("extent of resection", "CSF cytology", "date of progression", "craniospinal irradiation", "pathogenic germline") | Smaller set with a higher share of non-null annotations, at the cost of missing tersely worded notes |

Exceptions to the pattern: `diagnosis_recall` is the union of `dx_medulloblastoma`,
`dx_atrt` and the remaining embryonal entities, so both `dx_*` rows are subsets of it and it
is the patient-level join key; `diagnosis_ppv` narrows it by requiring diagnosis-establishing
language in the same note as the entity, since the entity is the task; `systemic_therapy_ppv` requires a
drug or protocol name AND dosing/cycle language; `medulloblastoma_recall` is the union of the
four evidence blocks the compact model summarizes (methotrexate, radiation, molecular group,
vital status) and `medulloblastoma_ppv` the phrase forms of the same; `document_topic` is a
single compact routing gate (entities, drugs, protocols and one anchor term per task) kept
short to stay well under the query-string clause limit; `document_type` matches title and
section cues only. Short abbreviations (CR/PR/SD/PD, CSI, RT, MTX, OSH, gene symbols) are always
gated by companion terms. Trailing wildcards (`resect*`, `chromosom*`) are used since the 2026-09-09
merge; wildcard terms are never placed inside quoted phrases, `progress*` is avoided because it
matches every "Progress Note" title (progression/progressive/progressed are listed instead), and
every slash, hyphen or caret is inside a quoted phrase so the query-string parser cannot read it
as an operator or regex. Wildcard terms bypass the analyzer; confirm the index lowercases them.

A `_recall` hit is a candidate for the task; a `_ppv` hit is a candidate more likely to yield a
non-null annotation. Neither establishes the fact. PPV and recall are untested until the
queries run against the server and a reviewed sample; adjust term lists from that sample rather
than from intuition. All `pcx_*` rows and `document_topic`/`document_type` were retired on 2026-09-09; each
`pcx_*` topic is superseded by its task-named pair.

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

The topic file contains 32 distinct topics. `pcx_molecular_pathology` and `pcx_radiation` were retired on 2026-09-09 (`radiation_recall` likewise supersedes `pcx_radiation`): under the intersection design `molecular_recall` covers a superset of its terms without the per-note disease gate, and `molecular_ppv` is the narrow form. `rx_chemotherapy` was added 2026-09-09 for the six backbone agents in `spreadsheet/rx_agent_*.csv` other than methotrexate; drug names stand alone like `rx_agent_methotrexate`, while abbreviations (VCR, CBDCA, CTX, CPM, CDDP, VP-16) require treatment context in the same note. `enc_transfer` (added earlier on 2026-09-09) was replaced the same day by `transition_of_care_recall` and `transition_of_care_ppv`, which select notes for `transition_of_care.py`: evidence that a patient was diagnosed, resected or treated elsewhere before presenting, which bears on the newly-diagnosed and no-prior-therapy criteria, on where the definitive surgery happened, and on where T₀ should be anchored. A hit is a screening flag for chart review, not a determination of transfer status. Both match transfer language alone (no disease-context gate, per the intersection design below) and have not been run against a server. Current structured population filters are ages 0–8 at visits and a minimum 365-day encounter span; these are separate from the text queries and can restrict the patient pool presented for review.

Lab retrieval is broader than numeric lab valuesets. The five folate variables and expanded AST/ALT, platelet and local creatinine definitions do not require adding every code to note-text queries. Interpret results using source documents and the [data dictionary](spreadsheet/data_dictionary.csv); topic hits alone do not populate those structured columns.
