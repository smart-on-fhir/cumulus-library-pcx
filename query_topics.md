# PCX clinical-note retrieval topics

Repository definitions checked 2026-09-10. These queries select candidate notes for
chart review and extraction; the names `ppv` and `recall` describe intended operating
points, not measured accuracy.

## Files and selection

- [query_topics.tsv](spreadsheet/query_topics.tsv) is a symlink to
  [query_topics_ppv.tsv](spreadsheet/query_topics_ppv.tsv), the current default.
- The PPV file contains 18 rows: four shared topics and 14 task-specific `_ppv` topics.
- [query_topics_recall.tsv](spreadsheet/query_topics_recall.tsv) contains 18 rows:
  the same four shared topics and 14 `_recall` topics.
- Across both files there are 32 distinct topic names. The `*.tsv~` files are backups,
  not the configured input.

Both files use exactly `topic` and `query` columns. Queries target `note` using
Lucene query-string syntax, not Kibana KQL. Keep grouping, quotes, wildcard stems
and phrase proximity intact when editing. Test acceptance and analyzer behavior
in the deployment environment; a local syntax check cannot establish server limits
or clinical performance.

The query stage reads only `spreadsheet/query_topics.tsv`; it does not automatically
run both sets. To select recall, repoint that symlink to `query_topics_recall.tsv`
and use a fresh result destination. Preserve the chosen file and query version with
the run. The four shared names are identical between files, so cached output names
alone do not identify which query revision generated them.

## Topic boundaries

| Topic or task (task rows have `_ppv` / `_recall` suffixes) | Candidate evidence |
| --- | --- |
| `dx_medulloblastoma` | Named medulloblastoma, morphology codes and contextual historical PNET wording |
| `dx_atrt` | Named ATRT, morphology or contextual rhabdoid evidence for review/reclassification |
| `rx_contrast_methotrexate` | Methotrexate ingredients, brands and contextual MTX abbreviation across formulations |
| `rx_chemotherapy` | Six backbone agents represented by `rx_chemo_*` valuesets; methotrexate is separate |
| `diagnosis` | Broader CNS tumor entities and diagnosis-establishing language; recall is not specific to medulloblastoma |
| `transition_of_care` | Outside diagnosis, surgery or therapy, transfer/referral and entry to the current institution |
| `surgery` | Resection, biopsy, residual disease, second-look surgery and dates |
| `metastasis` | Chang stage, CSF cytology, neuraxis imaging and metastatic sites |
| `molecular` | Molecular subgroup, methylation/assay provenance and alterations |
| `systemic_therapy` | Agents, protocols, regimens, doses, cycles and stem-cell rescue |
| `radiation` | Planned/delivered radiation, fields, doses, timing and explicit omission |
| `response` | Response assessments, evaluable disease and treatment milestones |
| `event` | Progression, recurrence, remission, secondary malignancy and death |
| `patient` | Timeline anchors, vital status and follow-up |
| `laboratory` | Organ function, methotrexate levels/clearance and toxicity evidence |
| `predisposition` | Germline testing and reported findings |
| `registry_eligibility` | Evidence relevant to a separate ACNS0334-like eligibility assessment |
| `medulloblastoma` | Compact discovery summary: treatment, molecular group and survival evidence |

The 14 task names correspond to extraction modules. `base.py` and `treatment.py`
provide shared definitions; `document_topic.py` and `document_type.py` provide routing
and classification rather than dedicated retrieval pairs. Retrieval labels do not
populate annotation fields automatically. Old `pcx_*`, `pnoc30_*`, `enc_transfer`,
and `rx_agent_methotrexate` labels are not current query rows.

## Context and patient intersections

Most task pairs combine specific evidence with a same-note context gate:

```text
ppv    = specific evidence OR (oncology context AND narrower task evidence)
recall = ppv               OR (oncology context AND broader task evidence)
```

The actual TSV expressions govern: diagnosis has its own entity/diagnostic-evidence
logic, surgery uses a broader neurologic context, and transition-of-care has no
ungated branch. Selected specific phrases and drug/protocol terms can retrieve notes
without a repeated diagnosis. Broad context words alone are insufficient. The recall
file includes the PPV expression for the 13 non-diagnosis task pairs; diagnosis uses
a separate broad entity union.

Intersect task results with the intended patient cohort downstream. For a
medulloblastoma cohort, use the appropriate reviewed diagnosis evidence or structured
case definition; `diagnosis_recall` also retrieves other CNS tumors. A patient-level
intersection does not remove the query's same-note context requirements. Follow-up
notes without those anchors may be missed, which can affect both note and patient
coverage. The structured age-at-visit 0–8 and minimum 365-day encounter-span filters
are additional, independent restrictions (see [limitations](limitations.md)).

Same-note co-occurrence does not prove that a procedure treated the tumor. Negated,
historical, planned and uncertain text may be useful evidence; chart review must
separate these from delivered treatment, confirmed diagnoses and patient-specific
facts. Topic hits do not establish high-dose methotrexate, protocol enrollment,
causality, toxicity, or event-free survival. Remission is not automatically an adverse
EFS event. Lab retrieval also includes text/coded evidence absent from numeric wide
fields; see [folate review](folate_review.md).

## Response query revision

**Response pair, 2026-09-10.** After a first run of `response_ppv` returned 509,882 documents,
its generic branch — oncology term anywhere AND imaging anywhere AND a status word anywhere —
was removed. `response_ppv` now has a small ungated arm ("tumor response", RANO, RAPNO, "no
residual tumor", measurable/evaluable disease) and, under the oncology gate, explicit response
phrases; residual enhancement and interval change count only as proximity phrases with a tumor
noun, milestones only with an assessment term, cytology only with a milestone or assessment
term. `response_recall` embeds that PPV and adds, under the gate, 80 noun×status proximity
phrases (tumor/mass/lesion/enhancement/cavity/residual/metastases × stable/unchanged/resolved/
decreased/increased/smaller/larger/progression/progressed/response, slop 5) in place of bare
`MRI`, `stable`, `response`. The same audit is to be applied to the other pairs only after the
response counts (documents and distinct patients, globally and within `dx_medulloblastoma OR
dx_atrt`) show the change worked. The file is now split: `query_topics_ppv.tsv` (the
`query_topics.tsv` symlink target) and `query_topics_recall.tsv`.

The 509,882-document count records the earlier run reported during development; it
is not a result for the revised query. No new result counts were verified in this
documentation refresh. Compare distinct notes and patients before and after revision,
both globally and within the intended disease cohort, and review missed as well as
retrieved notes before claiming improved accuracy.

## Site adaptation and execution

`transition_of_care` includes home-institution terms such as BCH and Boston Children's;
review these for each participating site. Confirm tokenization of hyphens and wildcard
case handling. The response queries use phrase proximity; query length and visible
clause counts alone do not establish server acceptance.

The current entry points are:

- `python -m cumulus_library_pcx.stage.elastic_query`: calls the rapid-elastic batch
  pipeline with the selected topic file and configured output directory.
- `python -m cumulus_library_pcx.stage.elastic_output`: generates upload/union artifacts
  from CSV results in the configured dated output directory when results exist.

These commands perform work; they were not run for this documentation update.
`elastic_query` is commented out in the main manifest. `elastic_output` is registered
with `skip_by_default=true`, and its current submanifest references an external dated
upload manifest. The default structured build does not execute retrieval or import
those results. External results and upload availability were not inspected here.
Use a fresh output directory for revised queries because cached topic results can be
reused; exclude obsolete result files before generating an upload manifest.

The repository also provides `tools/elastic_query_print_tree.py` and
`tools/elastic_results_print_topic_overalaps.py` for inspection. Local checks of TSV
headers, unique names, quotes, parentheses and pair inclusion are structural checks,
not validation of Elasticsearch execution or LLM extraction. The existing custom
Elastic case/task SQL is separate from the generated union; inspect its topic filters
before using it with the current labels.
