# PCX clinical-note retrieval topics

These queries select candidate notes for chart review and extraction. Query definitions were
last reviewed 2026-09-10; this page was brought up to date 2026-10-09.

## Files and selection

Topics use the rapid-elastic format: a folder with one `<topic>.txt` per topic, where the
file name is the topic and the whole text is the query. The only folder is
`spreadsheet/query_topics/`. It holds shared topics (`dx_*`, `rx_*`) and one topic per
extraction task, taken from the precision-leaning set. The earlier separate precision (`ppv`)
and recall folders are no longer in the repository.

Each file is one line with no trailing newline. Queries target `note` using
Lucene query-string syntax, not Kibana KQL. Keep grouping, quotes, wildcard stems
and phrase proximity intact when editing. Test acceptance and analyzer behavior
in the deployment environment; a local syntax check cannot establish server limits
or clinical performance. Use a fresh result destination whenever a query changes, and keep
the query version with the run: cached output names alone do not identify which query
revision generated them.

## Topic boundaries

| Topic | Candidate evidence |
| --- | --- |
| `dx_medulloblastoma` | Named medulloblastoma, morphology codes and contextual historical PNET wording |
| `dx_atrt` | Named ATRT, morphology or contextual rhabdoid evidence for review/reclassification |
| `rx_contrast_methotrexate` | Methotrexate ingredients, brands and contextual MTX abbreviation across formulations |
| `rx_chemotherapy` | Six backbone agents represented by `rx_chemo_*` valuesets; methotrexate is separate |
| `diagnosis` | Broader CNS tumor entities and diagnosis-establishing language; not specific to medulloblastoma |
| `transition_of_care` | Outside diagnosis, surgery or therapy, transfer/referral and entry to the current institution |
| `surgery` | Resection, biopsy, residual disease, second-look surgery and dates |
| `metastasis` | Chang stage, CSF cytology, neuraxis imaging and metastatic sites |
| `molecular` | Molecular subgroup, methylation/assay provenance and alterations |
| `systemic_therapy` | Agents, protocols, regimens, doses, cycles and stem-cell rescue |
| `radiation` | Planned/delivered radiation, fields, doses, timing and explicit omission |
| `response` | Response assessments, evaluable disease and treatment milestones |
| `event` | Progression, recurrence, remission, secondary malignancy and death |
| `survival_timeline` | Timeline anchors, vital status and follow-up |
| `laboratory` | Organ function, methotrexate levels/clearance and toxicity evidence |
| `registry_eligibility` | Evidence relevant to a separate ACNS0334-like eligibility assessment |
| `medulloblastoma` | Compact discovery summary: treatment, molecular group and survival evidence. Its extraction model was replaced by `diagnosis`, so no task reads it now |

The task topics are named after extraction modules in `cumulus_library_pcx/llm/models/`.
`document_topic` and `document_type` route and classify notes and have no retrieval topic.
Retrieval labels do not populate annotation fields automatically.

## Context and patient intersections

Most task topics combine specific evidence with a same-note context gate:

```text
topic = specific evidence OR (oncology context AND narrower task evidence)
```

The query text in each file governs: diagnosis has its own entity and diagnostic-evidence
logic, surgery uses a broader neurologic context, and transition-of-care has no ungated
branch. Selected specific phrases and drug or protocol terms can retrieve notes without a
repeated diagnosis. Broad context words alone are insufficient.

Intersect task results with the intended patient cohort downstream. For a
medulloblastoma cohort, use the appropriate reviewed diagnosis evidence or structured
case definition; `diagnosis` also retrieves other CNS tumors. A patient-level
intersection does not remove the query's same-note context requirements. Follow-up
notes without those anchors may be missed, which can affect both note and patient
coverage. The structured minimum 365-day encounter-span filter is an additional,
independent restriction; the study population has no age restriction (see [limitations](limitations.md)).

Same-note co-occurrence does not prove that a procedure treated the tumor. Negated,
historical, planned and uncertain text may be useful evidence; chart review must
separate these from delivered treatment, confirmed diagnoses and patient-specific
facts. Topic hits do not establish high-dose methotrexate, protocol enrollment,
causality, toxicity, or event-free survival. Remission is not automatically an adverse
EFS event. Lab retrieval also includes text/coded evidence absent from numeric wide
fields; see [laboratory data](laboratory.md).

## Response query revision

**Response topic, 2026-09-10.** After a first run returned 509,882 documents, its generic
branch (oncology term anywhere AND imaging anywhere AND a status word anywhere) was removed.
`response` now has a small ungated arm ("tumor response", RANO, RAPNO, "no residual tumor",
measurable/evaluable disease) and, under the oncology gate, explicit response phrases;
residual enhancement and interval change count only as proximity phrases with a tumor noun,
milestones only with an assessment term, cytology only with a milestone or assessment term.

The 509,882-document count records the earlier run reported during development; it is not a
result for the revised query. No new result counts have been verified. Compare distinct
notes and patients before and after a revision, both globally and within the intended
disease cohort, and review missed as well as retrieved notes before claiming improved
accuracy.

## Site adaptation and execution

`transition_of_care` includes home-institution terms such as BCH and Boston Children's;
review these for each participating site. Confirm tokenization of hyphens and wildcard
case handling. The response queries use phrase proximity; query length and visible
clause counts alone do not establish server acceptance.

The entry points are:

- `python -m cumulus_study_builder.tools.elastic_query`: runs every topic in
  `spreadsheet/query_topics/` through rapid-elastic and writes result CSVs under
  `$ELASTIC_OUTPUT_DIR` (else `$CUMULUS_LIBRARY_DATA_PATH/elastic/output`).
- `cumulus-study build elastic_upload`: when result CSVs exist in that folder, writes
  `file_upload_elastic.toml` beside them and schedules the upload plus the
  `pcx__elastic_union` table. With no CSVs the stage builds an empty `pcx__elastic_union`,
  so SQL that reads it runs at a site without Elasticsearch. `elastic_upload` is a default
  stage ([cumulus-study.md](cumulus-study.md)).

Use a fresh output folder for revised queries because cached topic results can be reused;
remove obsolete result files before building the upload.

Local checks of file names, quotes and parentheses are structural checks, not validation of
Elasticsearch execution or LLM extraction.
