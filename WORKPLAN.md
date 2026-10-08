# Workplan: cumulus-library-pcx (prefix `pcx`)

Open, study-specific work only, on cumulus-study-builder **0.5.5**, the git tag `v0.5.5` (not on
PyPI). Install it from `smart-on-fhir` with
`pip install "git+ssh://git@github.com/smart-on-fhir/cumulus-study-builder.git@v0.5.5"`, then
`pip install -e '.[test]'`; the release workflow needs read access to that repository. Done work is in
[CHANGELOG.md](CHANGELOG.md).
Sections follow [PROTOCOL.md](PROTOCOL.md) (a section with nothing planned says so), then Build, tests and docs.
Each entry: priority · `stage` · task. Paths are under the study package `cumulus_library_pcx/`.
**P1** before the next warehouse, export or NLP run · **P2** correctness or usability · **P3** cleanup.

Medulloblastoma (Group 3 first): do the ACNS0334 treatment-associated outcome differences
appear in EHR cohorts? The study builds a discovery cohort and a trial-like cohort
([§1](PROTOCOL.md#1-objective), [§6](PROTOCOL.md#6-eligibility)). The diagnosis task version
must be fixed before NLP results are used ([§5](PROTOCOL.md#5-clinical-notes)); the
treatment-effect analysis is not yet specified ([§8](PROTOCOL.md#8-analysis)).

Runs on 0.5.5 with the `cumulus_library_pcx/` package (validated 2026-10-08 against the
`v0.5.5` tag: `skills check`, `starter check`, build, validate, 72 tests).

Releases are **built-artifact-only** PyPI packages: rendered SQL, TOML and JSON with no Python
code and no dependencies, built from the builder tag (DevOps, 2026-10-02). Sites install one
next to Cumulus Library, so neither the site nor the package needs cumulus-study-builder.

- **0.3.0**: the eight default stages. Tagged `v0.3.0`; the PyPI upload is the open item under
  Build, tests and docs.
- **0.4.0**: the first LLM workflow. Planned below.

## Release 0.4.0: document LLM tasks

CHOP must run the LLM on its own notes (no PHI leaves the site; CHOP has the Cumulus core
tables and AWS Bedrock, and runs `gpt-oss-120b`, the same model as BCH).

In scope: `nlp_document_tasks.workflow`, with its two tasks `document_type` and
`document_topic` (both version 2). They select their notes from `pcx__sample_task`, which the
default `sample` stage builds at every site: casedef notes at CHOP, casedef plus Elasticsearch
notes at BCH.

Out of scope: `nlp_clinical_tasks.workflow` and its 12 selector tables, `llm_clinical_wide`,
`eligible`, `outcome`, `client_views`, `qa_athena`, and `llm_schema` (the only stage that runs
Python: the schemas ship already built).

In order:

- [ ] P1 · external · **Cumulus Library must authorise `pcx` to run NLP.** Against Athena,
  Cumulus Library 6.3.4 refuses NLP for a study whose prefix is not a key of its allowlist
  (`module_allowlist.json`), and the key there is `cancer_mtx`, not `pcx`. Read in the
  installed code, not yet run. Andy changes the entry to `"pcx": "cumulus_library_pcx"` in
  Cumulus Library (assumed possible, 2026-10-08). The study keeps the prefix `pcx`. Name the
  first Cumulus Library version that has the change in the release README. *Done when* a
  Cumulus Library release lists `pcx`.
- [ ] P1 · decision · **Ship `llm_document_wide` too?** Its two SQL files turn the raw LLM
  output into `pcx__llm_document_topic_wide` and `pcx__llm_document_type_wide`. Without it a
  site gets only the raw result tables. Recommended: ship it, still opt-in.
- [ ] P1 · `nlp_document_tasks` · **Run both tasks at BCH first.** Finish the Elasticsearch
  export (17 topics), build `pcx__sample_task`, and run the workflow on `gpt-oss-120b`.
  Record the note count, cost and failure count in PROTOCOL section 5, and confirm version 2
  is the version to release. *Done when* both wide tables are populated at BCH.
- [ ] P1 · release · **Ship the document workflow in the release script.**
  `release/make_data_release.py` assembles only default stages and rejects anything else.
  Add the opt-in `nlp_document_tasks` stage: the `.workflow` file (one manifest entry, no
  selector guard since builder 0.5.5) and the two schemas it
  names (`llm/schemas/pcx-document-type-annotation.json`,
  `pcx-document-topic-annotation.json`), which are not listed in any stage TOML. The check
  that rejects SQL reading LLM or NLP tables becomes: no Python but `__init__.py`, and every
  file a stage or workflow names is in the package. *Done when* the wheel holds the
  workflow, both schemas and no Python.
- [ ] P1 · release · **Smoke test from the wheel.** A clean venv with only Cumulus Library
  installs the wheel. `cumulus-library build -t pcx` runs the eight default stages on DuckDB,
  and the document workflow runs against Bedrock on synthetic notes. Needs the core tables
  and the site tables the stages read (`tests/column_contracts.json`), with or without rows.
  Settles the "Stock Cumulus Library" and "Allowlist name" questions below.
- [ ] P2 · docs · **Site run instructions.** In the README and the package README: the stage
  to name, and the options a site passes (`--note-dir`, `--etl-phi-dir`,
  `--nlp-provider bedrock`, `--nlp-model gpt-oss-120b`), with the Cumulus Library version
  from the first item.
- [ ] P1 · release · **Publish 0.4.0.** Set the version in `pyproject.toml`, build with the
  script, upload, tag `v0.4.0`. *Done when* 0.4.0 is on PyPI and tagged.

## Open questions

- [ ] **Allowlist name.** Cumulus Library's allowlist maps study `cancer_mtx` to the module
  `cumulus_library_pcx`; the planned allowlist PR renames it to `pcx`. Cumulus Library 6.3.4
  discovery (`cli.get_study_dict`) imports allowlisted modules and keys them by the manifest
  prefix, so the installed release should build as `-t pcx` without `--study-dir`. Read in
  the code, not yet run: the 0.4.0 smoke test confirms it. Running NLP needs more: see the
  first 0.4.0 item.
- [ ] **Stock Cumulus Library runs the NLP stages.** Cumulus Library 6.3.4 has an NLP runner
  with a Bedrock provider (`--nlp-provider bedrock`, `--nlp-model`) and PCX's NLP stages are
  `config_type = "nlp"` workflows plus JSON schemas. Read in the installed package, not yet
  run: the 0.4.0 smoke test confirms it. If it fails, the stopgap is a source
  install of PCX and the builder at CHOP. A builder dependency in the package needs the
  builder on PyPI first.
- [ ] **Clinical-task selectors.** Decided 2026-10-08: each clinical task gets the notes the
  LLM marked relevant to its topic (`document_topic` results). To build: the 12
  `pcx__llm_document_task_*` tables from the document-topic wide table, in a study stage
  after `llm_document_wide`. They then leave `external_tables` in `cumulus-study.toml`.
- [ ] **Diagnosis version.** The removed `_50k` workflow ran diagnosis as version 3 and the
  remaining workflow says version 2, so version-3 rows already in a warehouse are excluded by
  the projection. Confirm 2 is the version to keep ([§5](PROTOCOL.md#5-clinical-notes)).
- [ ] `reviews/` was not migrated: restore or record as dropped
  ([§5](PROTOCOL.md#5-clinical-notes)). The query topics are restored, as one `<topic>.txt`
  per topic in `spreadsheet/query_topics_ppv/` and `query_topics_recall/`.
- [ ] **Inherited items: keep, schedule or close.** The 2026-09-11 workplan
  (`docs/source/workplan.md`) was removed 2026-10-08. Its items that are still open are listed
  under their sections below, marked "(was N.N)" with the old item number. The full text is
  in git history (tag `0.2-pre-study-builder`). None has been scheduled.

## Objective

No changes planned.

## Population

- [ ] P2 · `study_population` · **Utilization filter removes early deaths** (was 2.7).
  `include_utilization.csv` still requires 2 encounters spanning 365 days. For a survival
  population the old plan was 1 encounter and 0 days, with encounter count and span carried
  as covariates. The age half of 2.7 is done (ages 0-120, 2026-09-30).

## Variables

`dx_methotrexate_toxic.csv` was deduplicated 2026-10-08 (25 codes, one row each).

- [ ] P3 · `study_variable` · **High-dose methotrexate markers** (was 3.7). No valueset for
  methotrexate serum level (LOINC 3618-4, 14836-1, verify) or leucovorin / levoleucovorin.
  Then add both to `eligible_rx.sql` with their own first-day columns.
- [ ] P3 · `study_variable` · **Lab coverage** (was 5.8). Candidates to add: LOINC 753-4 to
  absolute neutrophil count, 42719-5 and 14631-6 to total bilirubin.

## Case definition

- [ ] P2 · `casedef` · **SNOMED 428061005 in two files** (was 2.3). Tier 1 `atrt` in
  `casedef.csv`, "Malignant tumor of brain" tier 3 in `dx_brain_cancer.csv`. Confirm the
  concept and keep it in one file. `dx_atrt.csv` still lists the generic C71.9 and 191.9.
- [ ] P2 · `casedef` · **ICD-O-3 morphology codes** (was 2.4). `dx_medulloblastoma.csv` has
  9470/3-9474/3. `casedef.csv` has none, so they never set time zero. The old plan: add them
  to casedef at tier 1 and derive `dx_medulloblastoma.csv` from casedef.
- [ ] P2 · decision · **sPNET arm** (was 2.5). ETMR, pineoblastoma and CNS embryonal never
  get a time zero. Either anchor `t0_day` on any non-ATRT tier 1 subtype, or record that this
  phase is medulloblastoma-only.
- [ ] P2 · decision · **Two time zeros** (was 2.6, 2.8). `pcx__cohort_casedef` anchors note
  sampling on the first casedef encounter of any subtype or tier. `eligible_dx.sql` anchors
  `t0_day` on the first tier 1 medulloblastoma encounter. Make the sampling anchor tier-aware
  or record that it is deliberately broader. Also undecided: whether time zero should come
  from the Condition onset or recorded date (`t0_condition_day` does not exist yet).

## Clinical notes

- [ ] P3 · `llm` · **Radiation indication enum** (was 3.6). `radiation.py` `indication` is
  free text. The old plan was a `RadiationIndication` enum, with a task version bump and
  regenerated schemas. The surgery-role half no longer applies: `eligible_surgery.sql` takes
  the earliest resection and has no free-text match.
- [ ] P3 · `llm` · **One validation switch** (was 4.6). `systemic_therapy.py`,
  `survival_timeline.py` and `registry_eligibility.py` still `raise ValueError` directly, outside the
  `CUMULUS_PCX_STRICT_MENTIONS` switch in `base.py`.

Otherwise no changes planned beyond the open questions above. The two `_50k` workflows were removed
2026-10-08, so each task has one definition and one version.

## Eligibility

- [ ] P2 · `eligible` · **Completed-months age** (was 1.8). `eligible_dx.sql` and
  `eligible_surgery.sql` use `DATE_DIFF('month', birthdate, day)`, which DuckDB and Athena
  may count differently near the 36-month boundary. The old plan: month difference of the
  truncated months, minus 1 when the day of month is earlier than the birth day.
- [ ] P2 · `eligible` · **One definition of chemotherapy** (was 3.4). Decided 2026-09-30:
  prior methotrexate excludes. Still open: the LLM branch of `eligible_rx.sql` counts every
  administered agent as chemotherapy (ondansetron would count). Restrict it to the seven
  study agents.
- [ ] P3 · `eligible` · **Radiation flags not gated on receipt** (was 3.3). `llm_proton_bool`
  and `llm_craniospinal_bool` in `eligible_radiation.sql` read every radiation row, so a
  planned proton round sets the flag.
- [ ] P3 · `eligible` · **History-of-irradiation codes** (was 3.5). The tier 2 codes (Z92.3,
  V15.3) are not used as prior-radiation evidence.
- [ ] P3 · decision · **ATRT from one note** (was 2.9). A single LLM note with subtype ATRT
  excludes. The old plan: require two notes or a pathology-typed note.
- [ ] P3 · `eligible`, `outcome` · **LLM date precision** (was 3.8). MONTH and YEAR precision
  dates are cast to exact days.

- [ ] P3 · `eligible` · `t0_source` is `'casedef_tier1_medulloblastoma'` even when `t0_day`
  is NULL (`eligible_dx.sql:59`); the header says tiers 2 and 3 (`eligible_dx.sql:6`),
  casedef has tiers 1-2.

## Outcomes

- [ ] P1 · `outcome` · **Death date parsing on Athena** (was 1.7).
  `outcome_vital_status.sql` uses `DATE(deceasedDateTime)`, which fails on Athena for a
  timestamp string. The old plan: `CAST(from_iso8601_timestamp(deceasedDateTime) AS DATE)`
  with a DuckDB macro in the tests. Before the first warehouse run of `outcome`.
- [ ] P2 · `outcome` · **Event-task death does not reach OS** (was 3.1).
  `outcome_first_event.sql` takes DECEASED from the event task. `outcome_vital_status.sql`
  does not, so such a death counts for EFS but not OS.
- [ ] P2 · `outcome` · **Events before time zero** (was 3.2). First-event candidates are not
  limited to `event_day >= t0_day`, so `efs_days` can be negative. Not re-checked since
  2026-09-11 beyond a search of the SQL.
- [ ] P3 · `outcome` · **Vital-status reconciliation** (was 3.9). The earliest death and
  latest alive dates win without cross-checking, and `efs_end_day` can exceed `os_end_day`.

## Analysis

- [ ] P2 · `client_views` · **Client views.** `client_timeline.sql` joins on encounter only;
  notes with conflicting dates get a NULL `note_author_date` and drop out of
  `client_diagnosis.sql`.
- [ ] P3 · `client_views` · **Use the builder's client views.** The builder's opt-in
  `client_views` stage has templates for `client_subject`, `client_encounter`,
  `client_timeline`, `client_timeline_latest`, `client_dictionary_coverage` and
  `client_timeline_events`; keep only `client_diagnosis`, `client_exposure`, `client_outcome`
  and overrides in `cumulus_library_pcx/sql/custom/client_views/` (builder rank 17). *Done when* the client
  tables and `spreadsheet/client_dictionary.csv` columns are unchanged.

## Build, tests and docs

- [ ] P2 · release · **Clinical workflow in a later release.** After 0.4.0: ship
  `nlp_clinical_tasks` and `llm_clinical_wide` once the 12 clinical-task selectors are built
  (open question above).
- [ ] P1 · release · **Publish 0.3.0 to PyPI** (DevOps, 2026-10-02): the eight default
  stages, on builder 0.5.5. The script makes a venv with the builder tag and the tested pins, renders,
  assembles, checks and builds the wheel and sdist into `build/release/dist/`
  ([README](README.md#release)). Publishing stays manual: Andy or @msa2984 runs the printed
  `twine upload` straight to PyPI (no TestPyPI), from `andy/study-builder` before the PR
  merges, then tags the release commit `v0.3.0`. *Done when* 0.3.0 is on PyPI and tagged.
- [ ] P3 · release · Optionally, a dispatchable GitHub Action that calls the script. It needs
  read access to the builder repository and a PyPI token or trusted publishing.
- [ ] P2 · tests · **Default plan test.** Assert `StudyManifest.get_stage('all')` contains none
  of the opt-in actions (`llm_schema`, NLP, wide tables, `eligible`, `outcome`, `client_views`,
  `qa_athena`).
- [ ] P3 · docs · **Stale SQL headers** (was 5.7). Six files in `sql/custom/outcome/` and
  `sql/custom/client_views/` cite "README section N" of the old README.
- [ ] P3 · tests · **Not re-checked since the builder move** (were 1.6, 1.10, 4.3, 5.5):
  `tier` typed INTEGER in the study-variable upload (the SQL casts it itself);
  `extra="forbid"` on the annotation models (none sets it); `client_timeline.sql` column
  binding on Athena; duplicated expressions across `eligible` and `client_views`.
- [ ] P3 · `qa_athena` · Optionally replace the study-owned `qa_athena` stage with the shared
  `Stage(qa)`.
