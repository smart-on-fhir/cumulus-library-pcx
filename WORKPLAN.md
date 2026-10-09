# Workplan: cumulus-library-pcx (prefix `pcx`)

Open, study-specific work only, on cumulus-study-builder **0.5.5**, the git tag `v0.5.5` (not on
PyPI). Install it from `smart-on-fhir` with
`pip install "git+ssh://git@github.com/smart-on-fhir/cumulus-study-builder.git@v0.5.5"`, then
`pip install -e '.[test]'`; the release workflow needs read access to that repository. Done work is in
the [Changelog](#changelog) at the end.
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

- [x] P1 · external · **Cumulus Library authorises `pcx` to run NLP.** Done 2026-10-08:
  Cumulus Library 6.3.5 lists `"pcx": "cumulus_library_pcx"` in `module_allowlist.json`
  (`cancer_mtx` is gone). Sites need Cumulus Library 6.3.5 or later to run the NLP stages
  against Athena. Not yet run: the smoke test below confirms it.
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

- [ ] **Allowlist name.** Cumulus Library 6.3.5 maps `pcx` to the module
  `cumulus_library_pcx`. Discovery (`cli.get_study_dict`) imports allowlisted modules and
  keys them by the manifest prefix, so the installed release should build as `-t pcx` without
  `--study-dir`. Checked 2026-10-09 on 6.3.5 with an editable install: `get_study_dict` finds
  `pcx`. The 0.4.0 smoke test confirms it from the wheel.
- [x] **Move the study to Cumulus Library 6.3.5.** Done 2026-10-09: `pyproject.toml` requires
  `>=6.3.5,<6.4` (the builder checkout too, not yet released), `requirements-tested.txt` pins 6.3.5, and skills check,
  starter check, build, validate and pytest (72 passed) pass on it.
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

Deferred model fields. None is scheduled: each is restored only if an analysis needs it.
Restoring one means a flat field on `DiagnosisAnnotation` (no mention wrapper), a task
version bump in `nlp_clinical_tasks.workflow`, regenerated schemas and wide SQL, and tests.
The previous enum values are in git history (`docs/source/deferred.md`, removed 2026-10-08).

- [ ] P3 · `llm` · **Integrated diagnosis (WHO CNS5)**, deferred 2026-09-10. Neither the
  classification (`CnsIntegratedDiagnosis`, 17 values) nor the verbatim phrase is extracted
  by any task now. Subgroup analyses use the molecular task's `molecular_group`. Before
  restoring, settle the validation question and avoid duplicating the molecular
  classification. The `document_topic` routing text for `diagnosis` still mentions the WHO-CNS5
  integrated diagnosis and primary site, which the diagnosis model no longer extracts.
- [ ] P3 · `llm` · **Tumor location and laterality**, deferred 2026-09-10 (`TumorLocation`,
  13 values; `Laterality`, 5 values). No location wording is extracted. Restore if an
  analysis needs surgical approach, neurologic outcomes or anatomical comparisons.
- [ ] P3 · `llm` · **Germline predisposition**, removed 2026-09-16. Not an ACNS0334
  criterion, exposure, stratum or outcome, and its relevance (SUFU/PTCH1, TP53) travels with
  SHH, not Group 3. Restore a small model only if an SHH-specific analysis needs
  radiation-avoidance or second-malignancy covariates.

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
  ([cumulus-study.md](cumulus-study.md#release)). Publishing stays manual: Andy or @msa2984 runs the printed
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

## Changelog

### 2026-10-09 — document tasks opt-in in the release

- The released `nlp_document_tasks` stage stays opt-in, as in the study (it ran by default
  earlier today). A default build runs the eight default stages, and a site runs the document
  tasks by naming the stage. The release check now requires `skip_by_default` on exactly
  the opt-in stages (`OPT_IN_STAGES`).

### 2026-10-09
- Data release (`release/make_data_release.py`) now ships `nlp_document_tasks.workflow` and
  runs it by default, plus all 14 LLM response schemas in `llm/schemas/`. The clinical NLP
  tasks ship as schemas only. New checks: no released stage skipped by default, every schema
  present in the package and wheel, every released NLP workflow's schema found.
- The release package's `pyproject.toml` now comes from `release/pyproject.toml.jinja`,
  rendered with the builder's `template.environment()`. The release no longer writes a
  README, and `twine check` runs without `--strict`.

### 2026-10-09 — Cumulus Library 6.3.5

- `pyproject.toml` requires Cumulus Library `>=6.3.5,<6.4`, the first release whose allowlist
  has `pcx`. `requirements-tested.txt` pins 6.3.5 after a passing run (skills check, starter
  check, build, validate, pytest 72 passed). The old 6.3.4 pin conflicted with the new floor,
  so the set-up commands and the release script could not install.
- Removed the stale `build/release/` (the 2026-10-08 0.3.0 build made with 6.3.4 and builder
  0.5.4). The next `release/make_data_release.py` run builds from scratch.

### 2026-10-08 — README-0.2.md removed

- `docs/source/README-0.2.md` (the pre-builder README) is removed. Carried over: the primary
  and secondary outcome definitions to PROTOCOL section 7; site requirements, the table
  glossary, the FHIR aliases and two environment variables to `cumulus-study.md`; the
  proof-of-concept framing to README.md.

### 2026-10-08 — deferred.md removed

- `docs/source/deferred.md` is removed. Its three deferred model items (integrated diagnosis,
  tumor location and laterality, germline predisposition) are in WORKPLAN under Clinical
  notes, and limitations.md section 6 says what their absence rules out. Two of its claims
  were out of date and were not carried over: the molecular task no longer extracts
  `integrated_diagnosis_verbatim`, and the diagnosis task no longer extracts primary-site wording.

### 2026-10-08 — MIGRATION.md removed, changelog moved here

- MIGRATION.md is removed. Its lasting content moved: the validation routine and the note on
  `tests/column_contracts.json` to `cumulus-study.md`, the Patient deceased-field site
  prerequisite to PROTOCOL section 7, and the "not patient-for-patient equivalent" note to
  the PROTOCOL decision log.
- The changelog is now the last section of WORKPLAN.md.

### 2026-10-08 — cumulus-study.md, README as a table of contents

- `docs/source/make-pcx.md` is replaced by `cumulus-study.md` at the repository root: set up,
  commands, the stage list, settings, environment, inputs and outputs, and the release,
  written for `cumulus-study`. The `make-pcx` manual is in git history.
- README.md is now a short table of contents. Its set up, edit, warehouse and release
  sections moved to `cumulus-study.md`.

### 2026-10-08 — LIMITATIONS.md at the repository root

- `docs/source/limitations.md` moved to `LIMITATIONS.md`. The dated "Current implementation
  findings (2026-09-11)" list is removed: most of it was fixed by the builder move and the
  2026-09-30 eligibility decisions, and what is still open is in WORKPLAN.md. Sentences in
  sections 1, 4, 5, 6 and 7 that described fixed defects are corrected.

### 2026-10-08 — Cumulus Library 6.3.5 allowlists pcx

- Cumulus Library 6.3.5 lists `"pcx": "cumulus_library_pcx"` in its module allowlist. The
  first 0.4.0 item in WORKPLAN is done. Moving the study's own pins to 6.3.5 is a new open item.

### 2026-10-08 — LLM.md at the repository root

- `docs/source/llm.md` moved to `LLM.md` and brought up to date: 12 clinical tasks with
  their current versions, `diagnosis` in place of the removed `medulloblastoma` model, no
  `_50k` workflows, a note-selection section, and `cumulus-study build` in place of
  `make-pcx`. Resolved integration gaps and dead links to `reviews/` were cut.

### 2026-10-08 — old workplan removed

- `docs/source/workplan.md` (2026-09-11) is removed. Its 21 still-open items are now in
  WORKPLAN.md under their sections, marked "(was N.N)", plus four listed as not re-checked. Done
  and superseded items were dropped. PROTOCOL and the other `docs/source` notes no longer cite its item numbers.

### 2026-10-08 — builder 0.5.5, selector guards removed

- The study requires cumulus-study-builder `>=0.5.5,<0.6` and installs the `v0.5.5` tag.
- The NLP selector guards are gone: no `nlp_<workflow>_guard.toml`, no
  `pcx__qa_selector_<workflow>.sql`, and each workflow is one entry in `manifest.toml`.
- An empty selector table now sends every note to the LLM. `pcx__sample_task` always has
  rows. The 12 clinical selectors must be checked by hand before `nlp_clinical_tasks` runs.

### 2026-10-08 — plan for release 0.4.0

- WORKPLAN has a "Release 0.4.0" section: the first LLM workflow, scoped to
  `document_type` and `document_topic` in `nlp_document_tasks.workflow`, with the ordered
  work to get there. PROTOCOL records the scope. Docs only.

### 2026-10-08 — release plan for 0.3.0

- 0.3.0 ships the eight default stages on builder 0.5.4. The NLP stages and the release smoke
  test move to the following release.
- Decided: CHOP runs `gpt-oss-120b`, and each clinical task will select the notes the LLM
  marked relevant to its topic. WORKPLAN and PROTOCOL record both.

### 2026-10-08 — document tasks select from pcx__sample_task

- `nlp_document_tasks.workflow` selects its notes from `pcx__sample_task` (casedef notes plus
  Elasticsearch notes), so the document tasks need no site-supplied table. The two
  `pcx__llm_document_task_document_*` names left `external_tables`.
- Both `_50k` workflows and their stages are removed. The document one was a copy of
  `nlp_document_tasks.workflow`.
- Removed `cumulus_library_pcx/nlp-selection-requirements.json`: it repeated the
  `external_tables` list in `cumulus-study.toml`, which is now the one place for it.

### 2026-10-08 — builder 0.5.4, pcx__sample_task

- The study requires cumulus-study-builder `>=0.5.4,<0.6` and installs the `v0.5.4` tag.
- New table `pcx__sample_task`, built by the `sample` stage: every casedef note (topic
  `casedef`) plus every Elasticsearch note (its search topic). A note appears once per topic.

### 2026-10-08 — elastic_upload is a default stage

- `elastic_upload` runs by default, before `sample`, so every site has `pcx__elastic_union`:
  empty at a site with no Elasticsearch export (CHOP), the uploaded results at a site with one.
  A default build at a site with an export now uploads its CSVs.
- `llm_schema` is opt-in. The default plan is eight stages with no Python.
- The release script ships `elastic_upload` and renders without an export, so the released
  union is the empty table.

### 2026-10-08 — builder 0.5.3

- The study requires cumulus-study-builder `>=0.5.3,<0.6` and installs the `v0.5.3` tag.
  The `elastic_upload` stage now always builds `pcx__elastic_union`: empty, with the same
  columns, when there are no export CSVs.

### 2026-10-08 — builder 0.5.2

- The study requires cumulus-study-builder `>=0.5.2,<0.6` and installs the `v0.5.2` tag
  (release script, README, WORKPLAN, `requirements-tested.txt`). 0.5.1 reads the query-topic
  folder. 0.5.2 fixes `cumulus-study build` stopping once the Elasticsearch export holds CSVs.

### 2026-10-08 — query topics in the rapid-elastic format

- Query topics are one `<topic>.txt` per topic (file name is the topic, text is the query):
  `spreadsheet/query_topics_ppv/` and `query_topics_recall/`, 17 topics each, with
  `spreadsheet/query_topics` a symlink to the PPV folder. The queries are unchanged from the
  TSVs, which are removed. `docs/source/query_topics.md`, PROTOCOL and WORKPLAN updated.

### 2026-10-07 — release plan: data-only, with NLP stages

- WORKPLAN: the PyPI release stays data-only (SQL, TOML, JSON) and now includes the NLP
  stages, so CHOP can run the LLM locally with stock Cumulus Library. New release items
  (script, smoke test) and open questions (CHOP note selection, model, further stages).
  PROTOCOL records the decision. Docs only: the release script is unchanged.

### 2026-10-07 — builder repository is smart-on-fhir

- The builder install URL is now `smart-on-fhir/cumulus-study-builder` (was `comorbidity/`)
  in the release script, README and WORKPLAN. Tag `v0.5.0` is the same commit there.

### 2026-10-07 — migration scaffolding removed

- PCX has no released version to migrate from, so the migration pins are gone: Andy deleted
  `tests/legacy_contract.json` and `docs/source_inventory.json`. The old repo is kept as git
  tag `0.2-pre-study-builder`. `spreadsheet/README.md`, MIGRATION and PROTOCOL no longer cite
  the deleted files.
- `tests/test_migration.py` is now `tests/test_stage_sql.py`. Kept: inputs validate, the
  stage-order SQL column check, the repeat-build check. Removed: the CSV, schema, workflow
  and count-table pins. Site-supplied tables come from `external_tables` in
  `cumulus-study.toml`.

### 2026-10-06 — release script uses filetool

- `release/make_data_release.py` finds the repository, the study package and the spreadsheet
  folder with the builder's `filetool` (`path_root`, `path_project`, `path_spreadsheet`), not
  `Path(__file__).parents[1]`. It now has to run from a Python with cumulus-study-builder
  installed (the development venv). README Release section says so.

### 2026-10-05 — data-only release script

- New `release/make_data_release.py` builds the data-only PyPI package: a venv with the
  builder tag, render and validate, then the seven default stages without NLP assembled into
  `build/release/package/` (`../spreadsheet/` paths moved inside the package), checked (no
  Python but `__init__.py`, no LLM or NLP tables) and built with flit into
  `build/release/dist/`. It prints the `twine upload` command and never uploads.
- README has a Release section. PROTOCOL and WORKPLAN record the release decisions: no
  TestPyPI, release from the branch, smoke test deferred.

### 2026-10-05 — medications from core, eligibility flags, ages 0-120

Ported from tag `0.2-pre-study-builder`:
- MedicationDispense hand-overs are structured evidence beside MedicationRequest orders in
  `eligible_rx.sql` and `client_exposure.sql` (new `*_dispense_first_day` columns). A dispense
  is not receipt.
- `pcx__eligible` keeps every subject: age under 36 months (at t0 and at surgery) and prior
  methotrexate, chemotherapy and radiation are flags. `pcx__eligible_trial` excludes on them,
  methotrexate included. Undated evidence is "not prior" (FALSE), and a missing t0 is NULL.
  `no_prior_chemotherapy_bool` and `no_prior_radiation_bool` are gone.
- Ages 0-120 (was 0-8) with adult age groups. The data and client dictionaries, three warn
  queries, test fixtures and contracts follow.

Also:
- The encounter count table drops `age_at_visit` and keeps `age_group`.
- PROTOCOL now cites `docs/source/README-0.2.md`.

### 2026-10-02 — builder from the v0.5.0 tag; version 0.3.0

- Setup installs cumulus-study-builder from its `v0.5.0` git tag (`git+ssh`, comorbidity
  repository). Re-validated against the tag: skills check, starter check, build, validate,
  70 tests.
- Removed `test_schema_generation_writes_one_schema_per_task`: the tag refuses schema writes
  outside the study, and `test_migration.py` already checks every built schema's hash.
- Removed `tests/data/synthetic`, which no test reads.
- Version 0.3.0 for the first data-only PyPI release (default stages without NLP). The plan
  is in WORKPLAN.md.

### 2026-10-02 — study-builder version replaces make-pcx; builder 0.5.0

- This is now the PCX repository's study: the make-pcx version is tag
  `0.2-pre-study-builder`, and this backport replaced it on branch `andy/study-builder`.
- Moved to cumulus-study-builder 0.5.0: the study package `study/` is now
  `cumulus_library_pcx/` (`cumulus-study.toml`, `.gitignore`, tests), `counts.workflow` sits at
  the package root, and `pyproject.toml` pins `cumulus-study-builder>=0.5.0,<0.6` and
  `cumulus-library>=6.3.4,<6.4`. `.gitignore` also ignores the agent folders skills sync
  creates (`.claude/`, `.codex/`, `.gemini/`).
- Removed `Stage(fhir_resource)` (medication tables come from Cumulus Library core) and the
  commented biostats demo (`analysis/`, `stage/biostats.py`, `sql/custom/biostats/`).
- `cumulus-study starter sync`: the starter record is now `.cumulus-starter-sha256.json`;
  `AGENTS.md` and `stage/llm_schema.py` follow the 0.5.0 starter.
- `tests/test_nlp_shapes.py` reads only NLP workflows, since `counts.workflow` now sits next
  to them.
- README setup installs the unreleased builder from a checkout (the `v0.5.0` tag once it
  exists), then builds before validating. `requirements-tested.txt` is refreshed: skills
  check, starter check, build, validate and 71 tests pass.

### 2026-09-24 — builder 0.5.0 inputs and docs

- WORKPLAN.md, PROTOCOL.md and MIGRATION.md now target cumulus-study-builder 0.5.0 after a
  code review; the code move itself is the P1 item in WORKPLAN.md.
- Removed `spreadsheet/include_diag_category.csv`: builder 0.5.0 no longer reads it and carries
  the same six report-category labels itself. Its hash left `tests/legacy_contract.json`.
- The builder's biostats module is not used outside IBD: the demo biostats scaffold is to be
  removed in the 0.5.0 move, not converted.

### 2026-09-22 — builder 0.4.1 release candidate

- Checked against the final cumulus-study-builder 0.4.1 candidate and cumulus-study-template
  v0.4.1: skills sync, template sync, validate, build and tests pass. `AGENTS.md` now points
  study-specific agent rules to a new `Agent rules` section at the end of `PROTOCOL.md`.

### 2026-09-22 — workplan by protocol section

- `WORKPLAN.md` headings are now the plain PROTOCOL.md section names (no numbers), every section listed ("No changes planned." when empty), Open questions first and Build, tests and docs last; the Summary heading was dropped, its text kept as the intro.
- `WORKPLAN.md` regrouped under the `PROTOCOL.md` section headings (plus Build, tests and docs);
  each entry tagged with priority and stage, decisions moved to the top. No tasks added or dropped.

### 2026-09-22 — workplan section titles

- `WORKPLAN.md`: P1, P2 and P3 items grouped under short titled headings (e.g. `P1 · Trial
  cohort eligibility`); a priority can now have several sections. No items changed.

### 2026-09-22 — workplan for builder 0.4.1

- `WORKPLAN.md` rewritten: open study work only, assuming cumulus-study-builder 0.4.1 and
  cumulus-study-template v0.4.1, under Summary / P1 / P2 / P3 / Decisions with links to
  `PROTOCOL.md`. Superseded workplans and reviews moved to `_to_delete/`.
- `pyproject.toml` requires `cumulus-library>=6.3.2,<6.4` (was `==6.3.1`), as builder 0.4.1 needs.
- Adopted builder 0.4.1: `tests/test_migration.py` reads upload `files` (falling back to `file`);
  `tests/column_contracts.json` drops `core__encounter.class_system`, adds `information_schema.columns`, adds `core__condition.category_system`/`category_display`
  and the DiagnosticReport `conclusioncode_*` columns; skills re-synced; validate, build and
  pytest pass on cumulus-library 6.3.2; `requirements-tested.txt` updated.

### 2026-09-22 — template sync adopted

- Counts moved to the builder's shared `counts` stage (counts skill):
  `study/sql/custom/counts/counts.workflow` defines the same 17 `pcx__cube_*` tables and
  replaces `study/stage/cube.py`, `study/cubes.json` and the two `_source` join tables. All
  tables count patients; encounter, document and report tables add the resource as
  `secondary_id`. Old files are in `_to_delete/`, with the root `counts*.workflow` drafts.
  `tests/test_counts.py` checks suppression and the variable-union join in DuckDB;
  `test_migration.py` expands the workflow in its count and column checks. Needs the current
  builder checkout (WORKPLAN P4): with it, validate passes and 71 tests pass, but only
  after temporary local fixes for P4's three unrelated breakages. The repo copy was not
  rebuilt.
- `WORKPLAN-sept-21.md` renamed to `WORKPLAN.md`, now the PCX workplan: shared S1–S4 marked
  done, the review's regression checks, priority meanings and provenance (runtime, wheel hash,
  what was not run) folded in from `README-sept-21.md`. `README.md` links it and now names the
  0.4.1 wheel it pins.
- NLP selector guards (builder 0.4.1): each of the four workflows now has a
  `study/nlp_<workflow>_guard.toml` and `sql/generated/pcx__qa_selector_<workflow>.sql`, listed
  ahead of the workflow under its own stage in `manifest.toml`. The guard counts the usable
  `note_ref` values (`DocumentReference/...`, `DiagnosticReport/...`) in every `select_by_table`
  and fails the stage when a selection has none, because cumulus-library 6.3.1 drops an empty
  selection and would send every note to the LLM. `cumulus-study.toml` gains
  `[builder] external_tables`, the 14 site-supplied `pcx__llm_document_task_*` tables from
  `study/nlp-selection-requirements.json`, so `validate` accepts selectors no stage builds;
  `tests/test_migration.py` gives those tables the `required_columns` of that file. Workflow
  files are unchanged.
- Regenerated with the current builder: `pcx__cohort_study_population_enc.sql` gains
  `enc_class_system` (builder joins encounter class on system and code).
  `tests/column_contracts.json` adds `class_system` to `core__encounter`, which cumulus-library
  6.3.1 has; the migration test failed on the new column without it.
- Count cubes keyed on encounters, notes, documents or reports now suppress on distinct
  patients as well (builder change, regenerated: 3 `pcx__cube_*` files). `min_subject` is no longer
  hard-coded in `study/cubes.json`; the builder default (`CUMULUS_CUBE_MIN_SUBJECTS`, 10) governs
  unless a spec sets its own.
- `pcx__cohort_casedef.sql` regenerated without the duplicate `history.subject_ref` in
  `longitudinal` (builder template fix); Athena had rejected the ambiguous reference.
- Skills re-synced from the 0.4.1 sdist (`skills check` clean: rxnorm cites Wasz et al., valueset writes discovery SQL, study-builder syncs before Orient).
- Builder pin moved from `==0.4.0` to `==0.4.1`; validate (now including the protocol section check), build and tests pass with the merged 0.4.1 tree.
- First `cumulus-study template sync --template ../../cumulus-study-template`: `.cumulus-template.json`
  now records the template path and the managed files (agent pointers, runtime adapter, generic
  notes) this study follows; seeds stay study-owned. Rebuilt and tests pass with the patched builder.
- Opt-in stage TOMLs now carry `skip_by_default` on every action (builder S1), so a default `cumulus-library build` no longer runs eligible, outcome, client_views, qa_athena or the LLM wide stages; `cumulus-study validate` flagged the old TOMLs before the rebuild.

### 2026-09-21 — re-aligned with the current builder and template

- Rebuilt the unreleased cumulus-study-builder 0.4.0 wheel from the 2026-09-21 checkout into
  `../baseline/dist` (the 2026-09-19 wheel is kept in `../baseline/dist-2026-09-19`). The
  `==0.4.0` pins are unchanged; `requirements-tested.txt` records the newly measured versions.
- Re-synced the managed agent skills: `study-encounter` is now `study-population`; rxnorm,
  study-variable, biostats and study-builder updated. `cumulus-study skills check` passes.
- Added the template's optional biostats scaffold (`analysis/exports.toml`, `analysis/README.md`,
  `study/stage/biostats.py`, `study/sql/custom/biostats/analysis.sql`) with `Stage(biostats)`
  commented out in `study/stage/manifest.py`, and a `biostats` extra in `pyproject.toml`.
- Added `spreadsheet/README.md`, `study/sql/template/README.md` and `study/sql/generated/README.md`.
- Rewrote `PROTOCOL.md` in the template's numbered sections (0-10) from the migration notes,
  the inherited documents and the 2026-09-19 review; rewrote `README.md`.
- Regenerated with the new builder: `pcx__cohort_study_population_observation_values` is no
  longer produced (Observation evidence now projects directly from `obs_base`), so
  `pcx__cohort_study_population_obs.sql` and `study/study_population.toml` changed.
- Validation: validate, build, skills check and 69 tests pass on a clean copy (Python 3.11.15,
  Linux). Warehouse execution was not run. CODE_REVIEW.md findings remain unapplied.
- Added `WORKPLAN-sept-21.md`: tasks from `README-sept-21.md`, referencing the shared
  `../WORKPLAN-sept-21.md`. Nothing applied yet.

### 2026-09-19 — builder backport

- Migrated from `cumulus-library-pcx` to cumulus-study-builder 0.4.0 and the study-template layout (prefix `pcx`, data package version 1 -> 2).
- 21 coded variables, 14 annotation models, four workflows, 23 NLP projections, eligibility, outcomes, client exports, QA and 17 count outputs retained; `HOME_INSTITUTION` resolves from local settings.
- Reviewed 2026-09-19: see CODE_REVIEW.md.
