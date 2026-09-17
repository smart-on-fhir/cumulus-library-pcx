# PCX extraction models

These models support an EHR reproduction of [ACNS0334 (PMC12833527)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/), prioritizing medulloblastoma and Group 3. They extract evidence from one document, not patient-level eligibility, randomized treatment assignment, survival duration or causal effects. Patient-level derivation happens in the eligible, outcome and client_views SQL stages ([eligible.md](eligible.md)).

| Model module                         | Task version | Study purpose                                                                                                                                                                      |
|--------------------------------------|-------------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `diagnosis`, `surgery`, `metastasis` | 2, 1, 1      | Original and revised diagnoses, age, definitive surgery, residual disease, MRI and CSF staging                                                                                     |
| `registry_eligibility`               | 1            | `TrialEligibilityAnnotation`: evidence for a separate trial-like cohort; the scientific discovery goal includes all ages, but current structured selection uses ages 0–8 at visits |
| `molecular`                          | 1            | Report-level classification and assay provenance; separate MYC/MYCN and gain/amplification; preserve conflicting calls. No wide table yet                                          |
| `systemic_therapy`, `treatment`      | 1            | Regimens, induction/consolidation, delivered versus planned doses, cycles and stem-cell infusion                                                                                   |
| `radiation`                          | 1            | Receipt, timing, field, dose and indication, including post-chemotherapy and salvage treatment                                                                                     |
| `response`                           | 1            | Baseline imaging/cytology evaluability and end-induction/end-consolidation response                                                                                                |
| `event`, `survival_timeline`         | 1, 2         | Dated disease events, distinct time anchors, death, last-known-alive and event-free follow-up                                                                                      |
| `laboratory`                         | 2            | Optional organ-function results and documented toxicity; prefer structured labs                                                                                                    |
| `medulloblastoma`                    | 1            | Broad any-dose discovery summary; insufficient alone for trial reproduction. Its `datetime.date` fields cannot be exported by cumulus-library 6.3.1 (see below)                    |
| `transition_of_care`                 | 1            | Transfer-in timing/reason, diagnosis and surgery setting, and therapy before entry                                                                                                 |
| `document_topic`, `document_type`    | 2, 2         | Routing to extraction topics and document classification                                                                                                                           |

Task versions live in the `.workflow` files: [nlp_clinical_tasks.workflow](cumulus_library_pcx/nlp_clinical_tasks.workflow) (13 clinical tasks) and [nlp_document_tasks.workflow](cumulus_library_pcx/nlp_document_tasks.workflow) (routing and classification). The `_50k` variants are strict subsets with identical prompts (diagnosis and surgery; document_topic only); nothing in them limits the note count. Bump a task's version whenever its model changes, and regenerate the schema and the wide-table snapshot together.

The paper's primary response endpoint uses baseline-evaluable patients and assesses complete response after consolidation. Early progression/death must remain in that denominator. Missing response is not complete response. EFS candidates include progression/relapse, secondary malignancy and death; remission is a response state. The [registered EFS definition](https://clinicaltrials.gov/study/NCT00336024) starts at enrollment. The outcome stage currently uses t0 (first tier 1 medulloblastoma encounter) as the EFS origin and censors at last known alive, marked provisional ([limitations.md](limitations.md) §3–§4).

Routine lab names are informed by the associated trial's [eligibility listing](https://www.mayo.edu/research/clinical-trials/cls-20126460) and registry. The article does not specify the full routine lab schedule. Numeric thresholds, age calculations, staging, dose classification and cohort selection are validated in the SQL stages, not in the models.

## Extraction conventions

- Diagnosis uses evidence-backed mentions; integrated-diagnosis wording is deferred ([deferred.md](deferred.md)), while historical diagnosis and primary-site wording remain. The shared evidence contract calls for nonempty verbatim spans for a present mention. Enforcement is warn-only by default: `base._mention_validation_issue` warns unless `CUMULUS_PCX_STRICT_MENTIONS=1`, which the test suite sets. Six per-model validators (systemic therapy administration, vital status, trial criterion, and the three compact-model evidence contracts) still raise unconditionally, so production behaviour depends on which field is wrong (workplan 4.6). Explicit negative tests and non-receipt are useful evidence. Silence is unknown.
- Dates with precision use ISO `YYYY-MM-DD`. Partial dates use first-of-period plus `MONTH`/`YEAR`; never treat those placeholders as exact survival dates. The eligible and outcome SQL currently `CAST(... AS DATE)` without consulting `*_precision` (warn table `pcx__warn_llm_date_coarse`, workplan 3.8). Exact-day-only fields in the compact discovery model keep partial dates null; detailed models preserve precision.
- Preserve distinct reports/events and disagreements for patient-level adjudication. A documented molecular group is not automatically methylation-confirmed.
- Planned doses are not actual administration. Protocol names do not establish receipt, full regimen completion or randomization.
- Actual ATRT diagnoses remain available for exclusion and retrospective reclassification. ATRT is not the required PCX diagnosis.
- Every `StrEnum` is KEY=VALUE with a sentinel; the sentinel is spelled seven ways across the package (`NONE_OF_THE_ABOVE`, `NOT_DOCUMENTED`, `NOT_AVAILABLE`, `UNAVAILABLE`, `UNKNOWN`, `NOT_REPORTED`, `UNEVALUATED`), some of which carry meaning (workplan 4.7).

## Remaining integration gaps

The document-topic model has 11 routing fields for 13 configured clinical tasks.
`medulloblastoma` and `transition_of_care` have retrieval queries but no router field;
their `select_by_table` tables are not automatically supplied by query hits. More importantly,
**no `pcx__llm_document_task_<task>` selection table is created by anything in the repository**,
and the document-routing workflow defines its own selection as the union of the clinical
selections, which is circular. The NLP stages cannot run until a selection stage exists (workplan 4.1).

`transition_of_care.py` now reads `HOME_INSTITUTION` from `tools/settings.py`, which reads the
`HOME_INSTITUTION` environment variable. The default in `settings.py` is inside the `os.environ.get()`
call, so it never applies: with the variable unset, regenerated descriptions say "care moved to None"
(workplan 1.3). The checked-in schema was generated with the BCH string; two examples in the module
still hard-code "BCH". Prior therapy before arrival at a site is distinct from prior therapy before
trial-like initial treatment.

The treatment-before-first-event flags and the chemotherapy/radiation sequence are implemented in
`pcx__outcome_exposure` (date comparison only). Surgery role and radiation indication are free text,
protocol naming differs across models (`protocol_name_verbatim` vs `protocol_name`), and the compact
medulloblastoma model cannot retain partial treatment dates. See the
[2026-09-10 model review](reviews/llm-models-review-2026-09-10/REVIEW.md) for the proposed enums; none
are implemented yet (workplan 3.6, 4.5, 4.7).

`MedulloblastomaGroup` / `MbMolecularGroup`, `EvidenceStatus` / `DeliveryStatus` and the two vital-status
shapes are still duplicated vocabularies (workplan 4.7). `pcx__client_diagnosis` sources the molecular
group from the compact model's wide table, which cannot be produced; the `molecular` task has no wide
table at all (workplan 4.5).

## Schema generation and wide outputs

Annotation classes use unprefixed names such as `DiagnosisAnnotation`; table names
retain the study prefix. From the repository root, generate schemas with:

```sh
export CUMULUS_LIBRARY_DATA_PATH=/path/to/local/data
export HOME_INSTITUTION="Boston Children's Hospital (BCH)"  # set to your site
python -m cumulus_library_pcx.llm.create_schema
```

Both environment variables are currently needed because of the settings defects described
above (workplan 1.3). This writes 16 schemas under `cumulus_library_pcx/llm/schemas/`,
one at a time; it does not run inference. An import failure can leave a partial update.
The diagnosis schema still declares `additionalProperties: false`, although its model
no longer forbids extra fields; resolve that drift before regenerating (workplan 1.10).

The wide templates (`llm/template/<prefix>__llm_*.sql.jinja`) project values without repairing
dates or adjudicating evidence:

- Scalar mentions produce one row per note; lists use `UNNEST ... WITH ORDINALITY`
  and a 1-based index. Systemic therapy has separate regimen, agent, administration,
  cycle and stem-cell-infusion tables; preserve their ordinal keys when joining.
- Each table starts with `note_ref`, `encounter_ref`, `subject_ref`, `origin`,
  `generated_on`, `task_version` and `system_fingerprint`. Clinical types map to
  BIGINT, DOUBLE, BOOLEAN or VARCHAR; diagnosis dates remain VARCHAR with precision.
- Diagnosis wide output omits mention flags and evidence spans. Retrieve those from
  the source NLP result; a projected value alone is not the full evidence record.
- Two stages own the templates: [nlp_clinical_wide](cumulus_library_pcx/stage/nlp_clinical_wide.py)
  renders the 21 clinical projections of `nlp_clinical_tasks.workflow` and
  [nlp_document_wide](cumulus_library_pcx/stage/nlp_document_wide.py) renders document type
  and topic from `nlp_document_tasks.workflow`. A template belongs to the workflow whose task
  name it starts with (`diagnosis_wide` → `diagnosis`), see `tools/nlp_wide.py`.

Generate the SQL and the stage manifests with:

```sh
make-pcx nlp_clinical_wide nlp_document_wide
```

Each template is rendered once as a `UNION ALL` over `<prefix>__nlp_<task>_<deployment>`
for the deployments in `settings.NLP_DEPLOYMENTS` (default `gpt_oss_120b`), filtered to
the task's `version` from its `.workflow`. Generation does not execute SQL or discover
source tables: every selected source table must exist with the expected result structure
when `cumulus-library build` runs the stage, and empty output means no usable source
results, not clinical absence. Older result structures require migration or
re-extraction; filtering row versions cannot repair an incompatible table schema.

The former Python builders (`llm/builder/pcx_*.py`, cumulus-library `BaseTableBuilder`s
with build-time source discovery) and their `tests/render_snapshots.py` are retired under
`_to_delete/llm/builder/`; the templates are the only generator of `llm/athena/`.

### Contract tests

`tests/test_nlp_wide_model_shape.py` checks that the `.workflow` files, the JSON schemas, the
Pydantic models, the templates and the saved `llm/athena/*.sql` agree: every task owns a
template and every template belongs to one workflow, every `nlp.result.<path>` a template
projects exists in its model (and no template projects spans or `has_mention`), the
rendered SQL pins the workflow version and unions deployments in sorted order.
`tests/test_nlp_clinical_wide.py` exercises the stage's `prepare_resources()` into a temp
directory. `llm/athena/*.sql` is build output, not source: it is not committed, and
`make-pcx` regenerates it before `cumulus-library build`.

The compact medulloblastoma task is configured but cannot be serialized by the
reviewed Cumulus 6.3.1 installation: `convert_pydantic_fields_to_pyarrow` rejects its
`datetime.date` fields (workplan 4.5). A renderable snapshot does not prove inference
or export works. Likewise, DuckDB checks do not validate Athena's nested `UNNEST`
execution; the transition-of-care projection uses `array_join`, which DuckDB lacks.

The [September 11 review](reviews/code-review-2026-09-11/REVIEW.md) records the historical
test failures and separates stale tests from unimplemented discovery and actual bugs.
At that review, the suite needed `CUMULUS_LIBRARY_DATA_PATH` and `PYTHONPATH=tests`
because of settings and a top-level test helper import; neither is needed now. Those
historical results are not a current test run.
