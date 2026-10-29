# Workplan: cumulus-library-pcx (prefix `pcx`)

Open, study-specific work only, on cumulus-study-builder **0.5.6** (git tag `v0.5.6`, not on
PyPI) and Cumulus Library **6.3.5**. Set up is in [cumulus-study.md](cumulus-study.md#set-up).
Done work is in the [Changelog](#changelog) at the end.
Sections follow [PROTOCOL.md](PROTOCOL.md) (a section with nothing planned says so), then Build, tests and docs.
Each entry: priority · `stage` · task. Paths are under the study package `cumulus_library_pcx/`.
**P1** before the next warehouse, export or NLP run · **P2** correctness or usability · **P3** cleanup.

Medulloblastoma (Group 3 first): do the ACNS0334 treatment-associated outcome differences
appear in EHR cohorts? The study builds a discovery cohort and a trial-like cohort
([§1](PROTOCOL.md#1-objective), [§6](PROTOCOL.md#6-eligibility)). The diagnosis task version
must be fixed before NLP results are used ([§5](PROTOCOL.md#5-clinical-notes)); the
treatment-effect analysis is not yet specified ([§8](PROTOCOL.md#8-analysis)).

Validated 2026-10-22 on builder 0.5.7 and Cumulus Library 6.3.5: build, validate and the
tests (98 passed).

Releases are **data-only** PyPI packages: the study's `manifest.toml` as is, every stage with
its `skip_by_default` flag, the rendered SQL, TOML and JSON, and no Python code. The one
dependency is Cumulus Library (`>=6.3.5,<6.4`), so neither the site nor the package needs
cumulus-study-builder ([cumulus-study.md](cumulus-study.md#release)). The next release is
**0.5.0**: the new `counts_kaplan` stage, initial-therapy exposures, date ranges and
systemic therapy v2. 0.4.3 on PyPI still has the old rules.

## Release 0.4.0

CHOP must run the LLM on its own notes (no PHI leaves the site; CHOP has the Cumulus core
tables and AWS Bedrock, and runs `gpt-oss-120b`, the same model as BCH).

The release ships every stage. What a site is expected to run first: the default stages,
then the opt-in `nlp_document_tasks` stage (`document_type` and `document_topic`), which
selects its notes from `pcx__sample_task`. The default `sample` stage builds that table at
every site: casedef notes at CHOP, casedef plus Elasticsearch notes at BCH. The clinical
workflow ships too but cannot run until its note-selection tables exist (open question below).

In order:

- [x] P1 · external · **Cumulus Library authorises `pcx` to run NLP.** Done 2026-10-08:
  Cumulus Library 6.3.5 lists `"pcx": "cumulus_library_pcx"` in `module_allowlist.json`.
  Not yet run: the smoke test below confirms it.
- [x] P1 · release · **Ship every stage in the release script.** Done 2026-10-09: the release
  copies the study manifest, every stage TOML and workflow, the rendered SQL and the LLM
  response schemas.
- [ ] P1 · `nlp_document_tasks` · **Run both tasks at BCH first.** Finish the Elasticsearch
  export, build `pcx__sample_task`, and run the workflow on `gpt-oss-120b`.
  Record the note count, cost and failure count in PROTOCOL section 5, and confirm the task
  versions to release. *Done when* both wide tables are populated at BCH.
- [ ] P1 · release · **Smoke test from the wheel.** A clean venv installs the wheel, which
  brings Cumulus Library 6.3.5. `cumulus-library build -t pcx` runs the default stages on
  DuckDB, and the document workflow runs against Bedrock on synthetic notes. Needs the core
  tables and the site tables the stages read (`tests/column_contracts.json`), with or without
  rows. Settles the "Stock Cumulus Library" and "Allowlist name" questions below.
- [ ] P2 · docs · **Site run instructions.** In `cumulus-study.md` and the package README:
  the stage to name, and the options a site passes (`--note-dir`, `--etl-phi-dir`,
  `--nlp-provider bedrock`, `--nlp-model gpt-oss-120b`).
- [ ] P1 · release · **Publish 0.4.0.** `pyproject.toml` says 0.4.0. Commit, build with the
  script, upload with the printed `twine upload` (Andy or @msa2984, straight to PyPI), tag
  `v0.4.0`. *Done when* 0.4.0 is on PyPI and tagged. Patch fixes after it go in 0.4.1.

- [ ] P1 · release · **Publish 0.5.0.** `pyproject.toml` says 0.5.0. Run
  `python release/make_chop_release.py`, then `cumulus-study build` to restore the BCH build,
  upload with the printed `twine upload`, tag `v0.5.0`, and publish the GitHub release notes.
  *Done when* 0.5.0 is on PyPI and tagged. At BCH, rerun systemic therapy v2 before the eligible
  stage (Clinical notes).

## Open questions

- [ ] **Allowlist name.** Cumulus Library 6.3.5 maps `pcx` to the module
  `cumulus_library_pcx`. Discovery (`cli.get_study_dict`) imports allowlisted modules and
  keys them by the manifest prefix, so the installed release should build as `-t pcx` without
  `--study-dir`. Checked 2026-10-09 on 6.3.5 with an editable install: `get_study_dict` finds
  `pcx`. The 0.4.0 smoke test confirms it from the wheel.
- [x] **Move the study to Cumulus Library 6.3.5.** Done 2026-10-09: `pyproject.toml` requires
  `>=6.3.5,<6.4` (the builder checkout too, not yet released), `requirements-tested.txt` pins 6.3.5, and skills check,
  starter check, build, validate and pytest (72 passed) pass on it.
- [ ] **Stock Cumulus Library runs the NLP stages.** Cumulus Library 6.3.5 has an NLP runner
  with a Bedrock provider (`--nlp-provider bedrock`, `--nlp-model`) and PCX's NLP stages are
  `config_type = "nlp"` workflows plus JSON schemas. Read in the installed package, not yet
  run: the 0.4.0 smoke test confirms it. If it fails, the stopgap is a source
  install of PCX and the builder at CHOP. A builder dependency in the package needs the
  builder on PyPI first.
- [ ] **Clinical-task selectors.** Decided 2026-10-08: each clinical task gets the notes the
  LLM marked relevant to its topic (`document_topic` results). To build: the
  `pcx__llm_document_task_*` tables from the document-topic wide table, in a study stage
  after `llm_document_wide`. They then leave `external_tables` in `cumulus-study.toml`.
- [ ] **Diagnosis version.** The removed `_50k` workflow ran diagnosis as version 3 and the
  remaining workflow says version 2, so version-3 rows already in a warehouse are excluded by
  the projection. Confirm 2 is the version to keep ([§5](PROTOCOL.md#5-clinical-notes)).
- [ ] `reviews/` was not migrated: restore or record as dropped
  ([§5](PROTOCOL.md#5-clinical-notes)). The query topics are restored, as one `<topic>.txt`
  per topic in `spreadsheet/query_topics/`.
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

- [ ] P3 · `casedef` · **Generic codes in dx_atrt.csv** (was 2.3). 428061005 and 93744007 are
  out of the casedef `atrt` rows (done 2026-10-22, see Changelog). `dx_atrt.csv` still lists the
  generic C71.9 and 191.9 (discovery only, not read by the eligible SQL).
- [ ] P2 · `casedef` · **ICD-O-3 morphology codes** (was 2.4). `dx_medulloblastoma.csv` has
  9470/3-9474/3. `casedef.csv` has none, so they never set time zero. The old plan: add them
  to casedef at tier 1 and derive `dx_medulloblastoma.csv` from casedef.
- [ ] P2 · decision · **sPNET arm** (was 2.5). ETMR, pineoblastoma and CNS embryonal get a time
  zero only from a day-precision LLM gold diagnosis date, never from a code. Either also anchor
  `t0_day` on any non-ATRT tier 1 subtype, or record that this phase is medulloblastoma-only.
- [ ] P2 · decision · **Two time zeros** (was 2.6, 2.8). `pcx__cohort_casedef` anchors note
  sampling on the first casedef encounter of any subtype or tier. `eligible_dx.sql` anchors
  `t0_day` on the LLM gold diagnosis day, else the first tier 1 medulloblastoma encounter. Make the sampling anchor tier-aware
  or record that it is deliberately broader. Also undecided: whether time zero should come
  from the Condition onset or recorded date (`t0_condition_day` does not exist yet).

## Clinical notes

- [ ] P1 · `eligible` · **Intrathecal / intraventricular methotrexate** (2026-10-22). Any
  administered methotrexate, any route, is now the exposure (done, see Changelog). Open, asked
  of the CHOP clinician: does intrathecal or intraventricular (Ommaya) methotrexate count? In
  infants that is a different, low-dose strategy from IV high-dose MTX. If not, exclude doses
  with `route IN ('INTRATHECAL', 'INTRAVENTRICULAR')` in `eligible_rx.sql` (they are already in
  `methotrexate_intrathecal_or_ventricular_*`). No NLP rerun needed.
- [ ] P1 · `nlp` · **Rerun systemic therapy** (2026-10-21). Each `pcx__nlp_<task>_<model>` table
  holds ONE task version: Cumulus Library builds it over the folder `..._v<version>` of the
  current workflow version, and `--clean` deletes the older folders. BCH, checked in Athena
  2026-10-21:
  - `systemic_therapy` is version 1 (external Parquet over `nlp_systemic_therapy_gpt_oss_120b_v1`,
    63,490 notes). The v2 templates name struct fields v1 lacks (`agent_name_verbatim`,
    `cycle_num`, `cycle_day`), so `llm_clinical_wide` FAILS at analysis until it is rerun, it is
    not empty. The selector `pcx__llm_document_task_systemic_therapy` has 139,015 rows over the
    same 63,490 notes (0 new, 0 omitted), so the rerun re-sends exactly those notes.
  - `radiation` is version 2 (44,968 notes), `document_topic` and `document_type` version 2
    (180,226 notes). They are kept only by NOT rebuilding them: a rebuild repoints the table at
    the workflow version and re-extracts every note. The radiation (2 or 3) and topic (1, 2 or 3)
    templates read whichever version the table holds.
  - Order: `--stage nlp_clinical_tasks --dev --nlp-subtask systemic_therapy` without `--clean-nlp`
    (`--nlp-subtask` exists only with `--dev` in Cumulus Library 6.3.5, and `--clean-nlp` deletes
    every `_v*` folder of the task), then
    `llm_clinical_wide`, `eligible`, `outcome`, `client_views`. `laboratory` (version 3) has
    never been run: `pcx__nlp_laboratory_gpt_oss_120b` exists with 0 rows, built over the empty
    `nlp_laboratory_gpt_oss_120b_v2` folder (checked 2026-10-21). Every struct field the
    laboratory templates read is in that v2 table, so `llm_clinical_wide` builds and the
    laboratory tables are empty until a `--dev --nlp-subtask laboratory` run repoints it at `_v3`.
  CHOP has not run notes yet and gets the current versions.
- [ ] P3 · `llm` · **Radiation indication enum** (was 3.6). `radiation.py` `indication` is
  free text. The old plan was a `RadiationIndication` enum, with a task version bump and
  regenerated schemas. The surgery-role half no longer applies: `eligible_surgery.sql` takes
  the earliest resection and has no free-text match.
- [ ] P3 · `llm` · **Validators are test-only** (was "One validation switch", 4.6). Cumulus
  Library validates responses against the JSON schema, so the `@model_validator` checks and
  `CUMULUS_PCX_STRICT_MENTIONS` run only in pytest. The checks that matter are SQL warn tables
  (`pcx__warn_llm_model_rule`, `pcx__warn_llm_date_invalid`). Open: the evidence rule (a finding
  needs verbatim spans) is unchecked, because the wide tables do not carry `has_mention` or
  `spans`. Also open: numeric limits remain in other schemas and discard the whole note when
  broken; the transition_of_care date `pattern` is the risky one. Remove them at each task's
  next version bump.

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
  dates are compared as exact days (the first day of the period). `<name>_day_precision` is
  carried in the wide tables and `client_timeline.date_precision`, but not yet into the
  `eligible` and `outcome` first-day columns.

## Outcomes

- [ ] P1 · `outcome` · **Death date parsing on Athena** (was 1.7).
  `outcome_vital_status.sql` uses `DATE(deceasedDateTime)`, which fails on Athena for a
  timestamp string. The old plan: `CAST(from_iso8601_timestamp(deceasedDateTime) AS DATE)`
  with a DuckDB macro in the tests. Before the first warehouse run of `outcome`.
- [ ] P2 · `outcome` · **Events before time zero** (was 3.2). First-event candidates are not
  limited to `event_day >= t0_day`, so `efs_days` can be negative. Not re-checked since
  2026-09-11 beyond a search of the SQL.
- [ ] P2 · `outcome` · **Reconcile undated events** (2026-10-21). An undated progression,
  recurrence or second malignancy makes the EFS interval NULL (`efs_censor_source =
  event_timing_uncertain`), even next to a dated event, and leaves exposures before the dated
  event unordered. Measure the rate on BCH data (`pcx__warn_outcome_first_event_timing`,
  `undated_event`), then decide how an undated mention is matched to a dated one or bounded
  (note date, for example).
- [ ] P3 · `outcome` · **Vital-status reconciliation** (was 3.9). The earliest death and
  latest alive dates win without cross-checking, and `efs_end_day` can exceed `os_end_day`.

## Analysis

- [ ] P2 · `client_views` · **Client views.** `client_timeline.sql` joins on encounter only.
- [ ] P3 · `client_views` · **Use the builder's client views.** The builder's opt-in
  `client_views` stage has templates for `client_subject`, `client_encounter`,
  `client_timeline`, `client_timeline_latest`, `client_dictionary_coverage` and
  `client_timeline_events`; keep only `client_diagnosis`, `client_exposure`, `client_outcome`
  and overrides in `cumulus_library_pcx/sql/custom/` (builder rank 17). *Done when* the client
  tables and `spreadsheet/client_dictionary.csv` columns are unchanged.

## Build, tests and docs

- [ ] P3 · builder · **Parallel table actions** (cumulus-study-builder 0.5.7, then PCX 0.4.1).
  Builder side done 2026-10-09, unreleased (its CHANGELOG "Unreleased"): the actions below
  are `SqlParallelAction`, and `validate` now rejects a parallel action whose files read each
  other's tables. PCX picks it up when it moves to that builder release; the 0.4.0 release
  builds from the `v0.5.6` tag and stays serial.
  Generated actions built their tables one at a time only because the builder's `SqlAction`
  defaults to `build:serial`. Checked 2026-10-09 on the rendered SQL: in these actions no
  table reads another in the same action, so each can be `SqlParallelAction`, as the
  `sample` aspects already are:
  - `study_population` aspects (enc, dx, rx, lab, obs, proc, doc, diag, allergy),
    `stage/study_population.py`
  - `study_variable` "variable cohorts" (every valueset cohort), `stage/study_variable.py`
  - `study_variable_wide` "variable union" and "variable wide" (dx, lab, proc, rx each),
    `stage/study_variable_wide.py`
  - `casedef` aspects (dx, lab, proc, rx), `stage/casedef.py`
  - also safe, same check, left serial for now: `study_meta` (meta_date, meta_version)

  These must stay serial, because a table reads another in the same action: `obs_base,
  lab_base` (`lab_base` reads `obs_base`), `casedef` "filter include/exclude" (`include`
  reads `candidate` and `exclude`), and the study-owned `eligible`, `outcome` and
  `client_views` chains. Build speed only: same SQL, same results. *Done when* PCX is on the
  builder release with this change, its rendered stage TOMLs show these actions as
  `build:parallel`, and build, validate and the tests pass.

- [ ] P2 · release · **Clinical workflow cannot run yet.** `nlp_clinical_tasks` and
  `llm_clinical_wide` ship opt-in, but need the clinical note-selection tables first
  (open question above).
- [ ] P3 · release · Optionally, a dispatchable GitHub Action that calls the script. It needs
  read access to the builder repository and a PyPI token or trusted publishing.
- [ ] P2 · tests · **Default plan test.** Assert `StudyManifest.get_stage('all')` contains none
  of the opt-in actions (`llm_schema`, NLP, wide tables, `eligible`, `outcome`, `client_views`,
  `qa_athena`).
- [ ] P3 · docs · **Stale SQL headers** (was 5.7). Six outcome and client_views files in
  `sql/custom/` cite "README section N" of the old README.
- [ ] P3 · tests · **Not re-checked since the builder move** (were 1.6, 1.10, 4.3, 5.5):
  `tier` typed INTEGER in the study-variable upload (the SQL casts it itself);
  `extra="forbid"` on the annotation models (none sets it); `client_timeline.sql` column
  binding on Athena; duplicated expressions across `eligible` and `client_views`.
- [ ] P3 · `qa_athena` · Optionally replace the study-owned `qa_athena` stage with the shared
  `Stage(qa)`.

## Changelog

### 2026-10-29 — Strict cohort cubes

- `pcx__kaplan_subject_demo` is renamed `pcx__kaplan_subject_strict`. Drop the old table in Athena.
- New exported `cube_kaplan_strict_os` and `cube_kaplan_strict_efs` count the strict cohort with the same columns as `cube_kaplan_os` and `cube_kaplan_efs`, which still count all subjects from `pcx__kaplan_subject`. New tables, so `data_package_version` stays 3. `test_strict_cohort` also builds the two strict cubes.

### 2026-10-29 — outcome.sql: missing END

- The `os_end_day` CASE in `outcome.sql` had lost its `END`, so the outcome stage failed to parse. Restored. No change to results.

### 2026-10-29 — Cubes of pcx__eligible and pcx__outcome

- `counts_kaplan.workflow` adds seven exported cubes of the tables that feed the Kaplan source: `cube_eligible_casedef`, `cube_eligible_prior_therapy`, `cube_eligible_risk`, `cube_eligible_exposure` (from `pcx__eligible`) and `cube_outcome_os`, `cube_outcome_efs`, `cube_outcome_initial_therapy` (from `pcx__outcome`). Floor of 1, like the Kaplan cubes. `stage/counts_kaplan.py` exports them.
- New `test_source_cubes_on_built_eligible_and_outcome` builds the cubes on the real eligible and outcome SQL over the seeded fixtures.

### 2026-10-29 — Kaplan protocol order by date, Conflicting ACNS0334 arm

- New `pcx__kaplan_subject.protocol_name_by_date`: the same protocols in first-documented order (earliest regimen start date, else the note date). Subject table only, the cubes keep the alphabetical `protocol_name`.
- `documented_trial_arm` says `Conflicting` instead of `Multiple` when notes document both ACNS0334 arms. Methotrexate exposure from Regimen B mentions is unchanged.
- New `test_protocol_order_by_date`.

### 2026-10-29 — Kaplan protocol_name lists every protocol

- `pcx__kaplan_subject.protocol_name` (and so the OS and EFS cubes) now lists every coded protocol a patient has, sorted and comma-joined (such as `ACNS0334,HEAD_START`), instead of `Multiple`. `documented_trial_arm` still says `Multiple` when both ACNS0334 arms are documented.

### 2026-10-29 — Kaplan strict cohort

- New `pcx__kaplan_subject_strict` in the `counts_kaplan` stage (not exported): medulloblastoma Group 3, Group 4 or non-WNT/non-SHH, with any ACNS0334, PBTC_026 or CCG99703 regimen (from `pcx__llm_systemic_therapy_regimen`, arm documented or not) or initial high-dose methotrexate, and a valid t0 with whole-month OS and EFS durations. Adds integer `os_months` and `efs_months` for plotting. New `test_strict_cohort`.

### 2026-10-29 — Kaplan cubes in months, with protocol and trial arm

- `pcx__cube_kaplan_os` and `pcx__cube_kaplan_efs` (`counts_kaplan.workflow`) now count survival in whole months (`overall_survival_months`, `event_free_survival_months`) instead of years, and add `protocol_name` and `documented_trial_arm` as their last columns. The cubes are no longer an exact PCX-30 column match. The years columns stay in `pcx__kaplan_subject`.
- `data_package_version` is unchanged (2), although the columns of two exported tables changed.

### 2026-10-29 — Kaplan subject protocol and trial arm

- `pcx__kaplan_subject` has new `protocol_name` and `documented_trial_arm`, from any systemic therapy regimen ever documented. `protocol_name` is the one coded protocol, Multiple, or Not Reported. `documented_trial_arm` is read from ACNS0334 regimens only: REGIMEN_A, REGIMEN_B, Multiple, Not Reported (ACNS0334 without an arm) or Not Applicable (no ACNS0334 regimen). The cubes are unchanged.

### 2026-10-29 — Kaplan subject survival in months

- `pcx__kaplan_subject` has new `overall_survival_months` and `event_free_survival_months` beside the years columns: whole months, FLOOR(days / 30.4375) (the year divided by 12), no cap, with the same Not Applicable and Not Reported rules. The OS and EFS cubes are unchanged (PCX-30 years layout).

### 2026-10-28 — qa_athena: Athena rejects IS NOT TRUE

- `pcx__warn_molecular_result_no_diagnosis.sql` used `IS NOT TRUE`, which DuckDB accepts but Athena (Trino) does not ("mismatched input 'TRUE'"), so the qa_athena stage failed. Now `IS DISTINCT FROM TRUE`: same result, NULL included, and valid in both engines.

### 2026-10-22 — version 0.5.0

- `pyproject.toml` 0.5.0, a minor release: new `counts_kaplan` stage, and changed columns in
  the eligible, outcome and client tables (initial-therapy flags, date ranges, systemic therapy
  v2). `data_package_version` stays 2: the Kaplan-Meier cubes are new tables and the existing
  count cubes are unchanged.
- `requirements-tested.txt` header describes the 2026-10-22 run (builder 0.5.7, 98 passed).
  Pins unchanged.

### 2026-10-22 — A month or year death date covers its whole period

- External review: a death documented as "January 2021" was a single day (January 15) when treatment was placed against the first event, so radiation on January 20 counted as after it and gave `had_initial_radiation = No` and `chemo_only_no_initial_radiation`. `outcome_vital_status.sql` now keeps `death_earliest_day` and `death_latest_day`, and `outcome_first_event.sql` uses them as the death's range. `death_day` stays at the middle of the period for durations.
- The earliest exact death day wins when no source's month or year ends before it: FHIR 2020-12-10 beside an LLM "2020" is 2020-12-10, not July 1, and not imputed.
- `client_exposure`: chemotherapy `administered_bool` comes from new `pcx__eligible_rx.chemo_administered_bool` (any LLM ADMINISTERED agent, dated or not), not from an administration date, as for methotrexate.
- New `test_a_month_or_year_death_covers_its_whole_period` fails on the old SQL.

### 2026-10-22 — Timeline administrations name their drug

- External review: `llm_therapy_administration` rows in `client_timeline.sql` had no drug, so two drugs given alike in one note became one row (`SELECT DISTINCT`, and the same `event_id`). The dose now joins its agent in the same extraction output (`note_ref`, `generated_on`, `regimen_index`, `agent_index`): `code` = agent, `code_system` = `pcx_llm_rx_agent`, and `rx_class` as on the agent rows. Route, dose, phase and status keep their columns.
- No administration identifier: rows identical in every exported field stay one row, so the timeline lists distinct administrations, not a dose count, and a note run twice does not double its doses.

### 2026-10-22 — Warn tables for the new date and exposure rules

- `pcx__warn_llm_duplicate_output` replaces `pcx__warn_llm_molecular_duplicate_output`: notes with more than one extraction output for the molecular, systemic-therapy or diagnosis task, each output's values in the detail.
- New `pcx__warn_exposure_timing_unknown`: treatment evidence whose timing is unknown, by reason. `prior_to_t0_unknown` (a month or year date straddles t0, so the subject is out of the trial view), `initial_unknown_event_timing`, `initial_unknown_possible_record`, `initial_unknown_outside_window_only`, and `methotrexate_intrathecal_or_ventricular_only` (sizes the open route question). Backed by new `*_initial_unknown_reason` columns on `pcx__outcome_exposure`.
- `pcx__warn_eligible_rx_llm_agent_unrecognized` also reads dose-level ADMINISTERED agents (same output), as `pcx__eligible_rx` does. `pcx__warn_llm_date_after_note` also checks administration dates and ACNS0334 Regimen B start dates, which date methotrexate exposure.
- Fixtures: `generated_on` on the diagnosis wide table, a second output for p8's systemic-therapy note and p1's diagnosis note, a temozolomide dose under a PLANNED agent (p10), a note date for note-p8-rx. New test for the straddle and intrathecal-only checks.

### 2026-10-22 — A dose joins its drug within the same extraction output

- `pcx__exposure_record.sql` (dose to agent, Regimen B to administration) and `eligible_rx.sql` (explicit non-receipt) now join on `generated_on` as well as `note_ref` and the array positions. A note run twice has two outputs whose agent positions can name different drugs. An external review showed a leucovorin dose from one output attaching to an explicitly-not-received methotrexate from the other, which fabricated methotrexate exposure and prior chemotherapy and removed the patient from the trial view. `generated_on` is set on every output by Cumulus Library; `system_fingerprint` can be NULL, so it is not a join key.
- Test fixtures: `generated_on` appended to the systemic-therapy agent, administration and regimen tables. New `test_a_dose_joins_its_agent_within_the_same_extraction_output` fails on the old joins.
- After the BCH systemic-therapy rerun, check `SELECT COUNT(*) FROM (SELECT note_ref FROM pcx__nlp_systemic_therapy_gpt_oss_120b GROUP BY note_ref HAVING COUNT(*) > 1)`.

### 2026-10-22 — Two generic brain cancer codes no longer mean ATRT

- `casedef.csv`: removed SNOMED 428061005 (malignant neoplasm of brain) and 93744007 (primary malignant neoplasm of CNS, per review lookup) from the tier 1 `atrt` rows. At BCH they gave 118 and 8 patients a tier 1 ATRT code, and 30 eligible patients were flagged ATRT on these codes alone (5 of them with a tier 1 medulloblastoma code), so they were wrongly out of the trial view. 428061005 stays a tier 3 candidate in `dx_brain_cancer.csv`. Patients whose only casedef evidence was one of these codes leave `pcx__cohort_casedef`, which also trims note sampling.

### 2026-10-22 — Dates are ranges: coarse and undated mentions no longer blank the analysis

- BCH Athena 2026-10-22: 62% of administered radiation mentions are undated, and 82% of radiated patients (220 of 269) have dated and undated mentions. Of 430 patients with progression, recurrence or second-malignancy mentions, 308 have both and 59 only undated ones, so the 10-21 rule left 85% of event patients without an EFS interval and with Unknown initial therapy. A fifth of dated radiation and a third of dated progression and recurrence dates are month or year dates.
- New `pcx__exposure_record` (eligible stage): every chemotherapy, methotrexate and radiation record with `earliest_day` / `latest_day`. A month or year date covers its whole period. An undated LLM mention ends at its note date (`pcx__llm_note_date`, FHIR note metadata, now built first in the eligible stage), and is a restatement (`restated_bool`) when a dated record of the same treatment starts on or before that date. `eligible_rx` and `eligible_radiation` read it. The `*_first_day_from_t0` columns added this morning are gone.
- Prior to t0: TRUE when a dated record ends before t0, NULL when a month or year date straddles t0 (so out of the trial view), undated evidence still never counts.
- Initial therapy (`outcome_exposure`): each record is inside, outside or possibly inside `[t0, first event)`, and restatements are ignored. TRUE needs a record inside, FALSE needs none inside or possible. The sequence is set only when one therapy certainly starts first.
- Events (`outcome_first_event`): the first event has `first_event_earliest_day` / `first_event_latest_day`. An undated mention in a note dated on or after the latest day is a restatement (`undated_event_restated_cnt`), otherwise it keeps `event_timing_uncertain_bool`. Events that are all undated stay events without an interval.
- Durations use the middle of a month or year (the 15th, July 1): `first_event_day`, `death_day`, `last_known_alive_day`, with `*_imputed_bool` flags and `os_end_day_imputed_bool` / `efs_end_day_imputed_bool` on `pcx__outcome`.
- Tests: coarse dates on both sides of t0 and of each other, undated restatements, an undated mention in a pre-t0 note, undated event mentions before and after the dated event. Also restores `test_sequence_uses_treatment_inside_the_window` and the pre-t0 plus in-window methotrexate case, which this morning's copy to the repo missed.

### 2026-10-22 — Initial-therapy methotrexate and radiation, Kaplan strata no longer "ever"

- Methotrexate exposure (`eligible_rx.sql`) is any LLM ADMINISTERED methotrexate, agent or dose level, any route (`llm_administered`, replaces `llm_high_dose`), or ACNS0334 Regimen B. CHOP clinician: any methotrexate given is high-dose. Evidence-only columns: `methotrexate_high_dose_*`, `methotrexate_intrathecal_or_ventricular_*`, `methotrexate_not_received_bool`. New `*_first_day_from_t0` and `*_undated_bool` in `eligible_rx` and `eligible_radiation`.
- `outcome_exposure.sql`: initial therapy is t0 to the first event (first day on or after t0, before the first event). `had_initial_methotrexate_bool`, `had_initial_chemo_bool`, `had_initial_radiation_bool` replace `*_prior_to_first_event_bool`: TRUE dated in the window, FALSE initial therapy documented without it (or explicitly not received), NULL unknown (no t0, uncertain event timing, undated exposure, nothing documented). `initial_therapy_sequence` comes from the same flags and adds NO_INITIAL_THERAPY.
- Behaviour changes: pre-t0 exposure is no longer initial (fixture p2 is now RADIATION_BEFORE_CHEMOTHERAPY, methotrexate FALSE), and under uncertain event timing an exposure on or after the dated event is now unknown, not FALSE.
- Kaplan cubes: `had_initial_methotrexate` and `had_initial_radiation` (Yes, No, Not Reported, Not Applicable) replace `ever_methotrexate` and `radiation`. Methotrexate given only after progression is now No, not Yes.
- `pcx__outcome`, `pcx__client_subject` (adds `had_initial_chemo_bool`), `pcx__client_exposure` (`had_initial_bool`), the warn tables, both dictionaries, PROTOCOL §6, §7 and §8.1, eligible.md and limitations.md follow. New test `test_initial_methotrexate_is_yes_no_or_unknown`.
- Review follow-up: `test_sequence_uses_treatment_inside_the_window` pins the diagnosis boundary. Chemotherapy before t0 no longer makes a radiation-first patient chemotherapy-first (the 10-21 SQL gave CHEMOTHERAPY_BEFORE_RADIATION), a subject without t0 gets no sequence, and methotrexate both before t0 and in the window is Yes.

### 2026-10-22 — Systemic therapy v2 prompt, BCH rerun command

- `systemic_therapy.py` (v2 amended in place, still not run anywhere): `high_dose_methotrexate_explicit_bool` no longer says "Numeric dose-based classification occurs downstream", which no SQL does and which invited the model to leave the flag null. Schema and summaries regenerated.
- P1 "Rerun systemic therapy": the command is `--dev --nlp-subtask systemic_therapy` without `--clean-nlp` (corrected from `--nlp-subtask` without `--clean`, which 6.3.5 rejects).
- New P1: any administered methotrexate counts as exposure (CHOP clinician), pending the intrathecal / intraventricular question.

### 2026-10-21 — NLP tables hold one task version: comments and plan corrected

- Comments in `llm_radiation_wide.sql.jinja`, `llm_document_topic_wide.sql.jinja` and both workflows no longer say older rows are "kept". Cumulus Library builds each NLP table over one `_v<version>` folder, so the multi-version filters read whichever version the table holds, never both. BCH keeps radiation v2 and topic v2 only by not rebuilding those tasks.
- P1 "Rerun systemic therapy" now records the BCH Athena checks (systemic therapy v1 over the `_v1` folder, 63,490 notes, selector matches exactly) and the order: `--nlp-subtask systemic_therapy` without `--clean`, then the downstream stages. `llm_clinical_wide` fails, not empties, until then.

### 2026-10-21 — Dates outside 1980 to today are cleared at the source, with their durations

- LLM dates: `sql/template/date_macros.sql.jinja` treats a well-formed date outside 1980-01-01 to the build day as not usable, so its `<name>_day` and precision are NULL in every `pcx__llm_*` table (all 21 regenerated). Downstream it behaves like an undated value: an implausible event date makes the event undated (EFS `event_timing_uncertain`), an implausible death date leaves the subject deceased with `death_day` NULL.
- FHIR: `pcx__outcome_vital_status` clears an implausible `deceasedDateTime` (still deceased, no FHIR death day) and ignores implausible encounter end days for `last_encounter_day`. A `deceasedDateTime` now sets `fhir_deceased_bool` even when its date is cleared.
- So `pcx__outcome`, `pcx__kaplan_subject` and the client views compute `os_days`, `efs_days` and `days_t0_to_first_event` only from plausible dates. The client guards stay as a backstop and now also clear `value_number` when they clear its date (client_outcome rows, client_timeline DERIVED rows).
- Warn checks: `llm_date_implausible` in `pcx__warn_llm_date_invalid`, `fhir_death_day_implausible` in `pcx__warn_outcome_vital_status_conflict`. Fixtures: Patient/p6 FHIR death 2031, Patient/p10 LLM diagnosis date 2031. `test_llm_dates.py` covers the window edges and today/tomorrow.

### 2026-10-21 — Molecular: one report row per subject across re-runs, molecular warn tables

- `pcx__client_diagnosis` now selects the molecular report as a single ROW (group, methods) with `MAX_BY`, never joined back by `note_ref#report_index`. Re-running the molecular task on a note produced two outputs with the same key, and the client table returned several rows per subject with mixed groups. All outputs are pooled. Order: real group, latest note, last report in the note, latest output (`generated_on`, `system_fingerprint`), then group and methods so the pick is deterministic.
- New warn `pcx__warn_llm_molecular_duplicate_output`: notes with more than one molecular extraction output, each output's groups in the detail.
- Reworked `pcx__warn_molecular_result_no_diagnosis` (real groups only): `molecular_no_diagnosis_evidence` (no named LLM diagnosis, no tier 1 casedef code), `molecular_diagnosis_not_medulloblastoma` (evidence exists, none of it medulloblastoma), `molecular_outside_discovery` (not in `pcx__eligible`). The first two are exclusive. Registered in `qa_athena.toml` and `pcx__warn_union`.
- Tests: molecular fixture `tests/data/warn/pcx__llm_molecular_report.csv`, `generated_on` and `system_fingerprint` appended to its schema, an ATRT-only diagnosis row for Patient/p10, expectations for both warn tables, and two re-run cases in `tests/test_client_diagnosis_sql.py` (fails on the old SQL with 9 rows for 7 subjects).

### 2026-10-21 — Molecular group: a real group is never replaced, method from the same report

- `pcx__client_diagnosis` picks ONE molecular report per subject and takes `molecular_group_ever` and `molecular_group_method` from that same report. Order: a real group (WNT, SHH, GROUP_3, GROUP_4, NON_WNT_NON_SHH) beats NOT_SUBGROUPED / INDETERMINATE, then the latest note (`pcx__llm_note_date`, undated notes last), then the last report in the note (`report_index`).
- An uncertain result is shown only when the subject has no real group. Previously a later NOT_SUBGROUPED / INDETERMINATE overwrote an earlier real group, and the method could come from a different report.
- `molecular_group_baseline` uses the same order among reports within 90 days of t0_day.
- Test `tests/test_client_diagnosis_sql.py` (fails on the old SQL). Fixture columns appended to `tests/data/schema.sql` and `tests/data/warn/pcx__llm_diagnosis_wide.csv`. Descriptions updated in `spreadsheet/client_dictionary.csv`.

### 2026-10-21 — Model rules checked in SQL, since the validators are test-only

- Cumulus Library validates each LLM response against the JSON schema, not the Python models,
  so the `@model_validator` checks never run at inference. New warn table
  `pcx__warn_llm_model_rule` applies them to the stored answers: administration date on a dose not
  ADMINISTERED, dose unit without an amount, negative dose, cycle number below 1, negative CD34,
  death date on a status not DECEASED, last known alive after death in the same note.
- `pcx__warn_llm_date_invalid` also lists `llm_date_precision_missing` (a date without its
  precision, or the reverse).
- Fixtures seed each check (administration rows for p2, new cycle and stem-cell CSVs for p8, an
  ALIVE survival note for p2 that does not move its outcome). llm.md, cumulus-study.md
  (`CUMULUS_PCX_STRICT_MENTIONS` is tests only) and the WORKPLAN validation item corrected.

### 2026-10-21 — Systemic therapy v2: no numeric limits in the schema

- `systemic_therapy.py` (v2 amended in place, not yet run): removed `ge=1` from the three
  `cycle_num` fields and `ge=0` from `dose_amount` and `cd34_cells_per_kg`. Cumulus Library
  validates each response against the JSON schema, so one out-of-range number discarded the whole
  note. Out-of-range values are now kept, to be flagged by SQL warn tables. Schema and summary
  regenerated, `test_llm_models` updated.

### 2026-10-21 — Note dates for every selected note, Elasticsearch notes included

- New `sql/custom/pcx__llm_note_date.sql` (first table of the `client_views` stage): one row per
  note in `pcx__sample_task`. DocumentReference author day else `date`, DiagnosticReport
  effectiveDateTime day else effectivePeriod start. Conflicting dates give NULL and
  `note_date_conflict_bool`. Replaces `pcx__sample_casedef_author`, which covered casedef notes only.
- `client_diagnosis.sql` left-joins it: diagnosis and molecular rows from Elasticsearch-only or
  undated notes are kept for the `_ever`, count and conflict columns, never baseline, and are the
  latest only when no dated note has a value (`note_order_day`). Was an inner join that dropped them.
- `client_timeline.sql` and `pcx__warn_llm_date_after_note` read the same spine (`note_date`, was
  `note_author_date`), so search-only notes get dates there too.
- Tests: `test_every_selected_note_gets_a_date`; the warn fixture is now `pcx__llm_note_date.csv`.
  client dictionary, cumulus-study.md and PROTOCOL updated.

### 2026-10-21 — Survival timeline notes: last visit, death documents and unlinked notes

- `pcx__llm_document_task_survival_timeline` keeps the last-visit notes (2026-10-20) and adds
  END_OF_LIFE_DOCUMENT and EXPLICIT survival_timeline notes from any visit, so a documented death
  is never dropped, and notes with no encounter or an encounter outside the study population
  (LEFT JOIN, was an inner join that dropped them). The LLM extracts those notes' dates.
- New `tests/test_document_task_sql.py` runs the selector SQL on eight hand-made notes; it fails
  on the old SQL. PROTOCOL 5 decision added.

### 2026-10-21 — Event-task death reaches OS and EFS alike

- `outcome_vital_status.sql` is the one place deaths are reconciled: it now adds event-task
  DECEASED mentions (new `llm_event_deceased_bool`, `llm_event_death_day`) to the FHIR and
  survival-timeline deaths, for `deceased_bool` and the earliest `death_day`.
- `outcome_first_event.sql` no longer reads DECEASED from the event task. Death comes only from
  vital status, so OS and EFS see the same death. EFS output is unchanged.
- `death_day_disagree` warn now compares all three death dates. New test
  `test_event_task_death_reaches_os_and_efs_alike`. Closes the P2 item "Event-task death does
  not reach OS". PROTOCOL 7 and the data dictionary updated.

### 2026-10-21 — Methotrexate exposure is high-dose, from dose-level receipt too

- `eligible_rx.sql`: methotrexate counts only from the LLM: an ADMINISTERED dose with
  `high_dose_methotrexate_explicit_bool` TRUE (`llm_high_dose`), or an ACNS0334 regimen with
  `documented_trial_arm = REGIMEN_B` (`llm_acns0334_regimen_b`, dated by the regimen start and by
  methotrexate administered in it). New `methotrexate_source`, `_high_dose_first_day`,
  `_regimen_b_first_day`, `_high_dose_bool`, `_regimen_b_bool`. `methotrexate_administered_*` removed.
- Structured methotrexate orders and dispenses are evidence only (`_order_first_day`,
  `_dispense_first_day`). Other methotrexate (intrathecal, not high-dose) is chemotherapy only.
- LLM receipt is the agent-level or the dose-level ADMINISTERED, earliest wins, for chemo too:
  a dose given under a PLANNED agent now counts.
- `systemic_therapy.py` v2 amended in place (no results yet): `documented_trial_arm` is the
  `TrialArm` enum (REGIMEN_A, REGIMEN_B, NONE_OF_THE_ABOVE) plus `documented_trial_arm_verbatim`.
  Schema, summaries and the regimen wide SQL regenerated.
- `client_exposure`, the `therapy_precedes_t0` and `exposure_order_only` warn checks, fixtures
  (new administration CSV), tests, eligible.md, PROTOCOL 6 and 7, limitations 2 and both
  dictionaries updated.

### 2026-10-21 — t0 from the LLM gold diagnosis day first

- `eligible_dx.sql`: `t0_day` is the earliest day-precision `diagnosis_gold_day` from a diagnosis
  note of any subtype (ATRT included), else the first tier 1 medulloblastoma encounter. New
  `t0_source` values `llm_diagnosis_gold` / `casedef_tier1_medulloblastoma`, NULL without a t0
  (was always the casedef label). New columns `casedef_t0_day` and `llm_t0_gold_day`.
- LLM-only and CHOP-roster subjects with a gold date now get a t0 and can reach the trial view.
- The two `dx_date_disagree` warn checks compare the LLM date with `casedef_t0_day` (comparing it
  with `t0_day` would compare the gold date with itself). `t0_anchor_casedef_later` can now fire.
- Fixtures: p6 and p8 gold dates are month precision, so they keep their seeded scenarios and test
  that a coarse gold date does not set t0. New test `test_t0_prefers_the_llm_gold_diagnosis_day`.
  eligible.md, PROTOCOL 2, 4 and 6, and the data dictionary updated.

### 2026-10-21 — CHOP roster rows are tier 2

- `sql/custom/pcx__cohort_casedef_include.sql` (CHOP): `subject_ref` is now `enc.subject_ref`
  (was the roster `patient_id`, which never matched the population), joined on `anon_id`.
- Roster rows are tier 2, not 1. They sit on every encounter of a listed patient, so as tier 1
  `eligible_dx` took the first encounter of any kind as t0. A roster-only patient is still a
  case-definition subject, with a NULL t0 unless a tier 1 medulloblastoma code sets it.
  `release/package` not updated: rebuild the release.

### 2026-10-21 — Why eligible_dx ages come from birthdate

- `eligible_dx.sql`: header comment now says why age stays in months from
  `core__patient.birthdate` rather than `core__encounter.age_at_visit` (whole years). No SQL change.

### 2026-10-21 — Undated EFS events are events, not censoring

- `outcome_first_event.sql`: `dated_event_bool` (was `any_event_bool`), plus
  `event_timing_uncertain_bool` (undated progression, recurrence or second malignancy),
  `death_undated_bool` and `event_documented_bool`. `undated_event_cnt` excludes deaths.
- `outcome.sql`: `efs_event_bool = event_documented_bool`. Undated events have NULL
  `efs_end_day` / `efs_days`, `efs_censor_source` `event_timing_uncertain` or `event_undated`.
- `outcome_exposure.sql`: prior-to-first-event flags are NULL when the timing is uncertain and
  the exposure is not on or after the dated event. An undated death never makes them unknown.
- `pcx__kaplan_subject.sql`: `initial_treatment_order` Not Reported when the timing is
  uncertain. `client_outcome.sql`, the `undated_event` warn check, dictionaries, PROTOCOL 7 and
  8.1, limitations 4 and tests updated. Open item: **Reconcile undated events** (Outcomes).
- `pcx__kaplan_subject.sql`: `diagnosis` is now `disease_subtype_ever` or Not Reported (was always
  Medulloblastoma). `test_counts_kaplan.py`, the data dictionary and PROTOCOL 8.1 match it.

### 2026-10-21 — Systemic therapy v2: coded values instead of free text

- `systemic_therapy.py`: `agent_name` is now `RxAgentName` (anticancer agents seen in BCH
  output, plus leucovorin, mesna and dexrazoxane as markers). Other supportive care
  (antiemetics, growth factors, antimicrobials, steroids) is no longer extracted. The note's
  own wording moved to `agent_name_verbatim`.
- `cycle_name` became `cycle_num` (int, as the note numbers it, not renumbered across phases)
  and `cycle_name_verbatim`. Administrations also get `cycle_day` (consolidation days count
  from the stem-cell infusion, day 0, so may be negative).
- New enums: `TreatmentProtocol` (`protocol_name`, next to `protocol_name_verbatim`, on
  regimens and cycles), `CycleCompletionStatus`, `AdministrationRoute`, `DoseUnit`.
- `treatment.py`: `TreatmentPhase` wording only adds what the standard terms lack (maintenance
  is POST_CONSOLIDATION, salvage is therapy for relapse or progression whenever given,
  pre-induction therapy is NONE_OF_THE_ABOVE). Shared with radiation and laboratory, so those
  bump too.
- Workflow: `systemic_therapy` 1 → 2, `radiation` 2 → 3, `laboratory` 2 → 3. BCH must not
  rebuild the radiation task: its table holds version 2 only, and `llm_radiation_wide.sql.jinja`
  reads `task_version IN (2, 3)` so either version works (corrected 2026-10-21, the table never
  holds both).
- SQL: `eligible_rx.sql` and `client_timeline.sql` match `agent_name = 'METHOTREXATE'`
  instead of `LIKE '%methotrexate%' OR '%mtx%'`. LLM chemo no longer counts the three
  supportive markers. `client_timeline` shows the coded agent and protocol, and cycle rows
  carry `cycle_num` in `value_number`. `pcx__warn_eligible_rx_llm_agent_unrecognized` lists
  agent and verbatim spelling.
- Tests: fixture `pcx__llm_systemic_therapy_agent.csv` uses coded agents (p1 gets a
  temozolomide row for the warn check), new `test_systemic_therapy_values_are_coded`.

### 2026-10-20 — Survival timeline notes come from the last clinical visit

- `release/package/.../sql/custom/pcx__llm_document_task.sql` adds the view
  `pcx__llm_document_task_survival_timeline` that `nlp_clinical_tasks.workflow` already selects by.
  Same relevance or `DOCUMENT_TASKS["survival_timeline"]` document types as the other task views,
  then only each subject's last clinical visit (latest encounter day among those notes), since
  there are no visits after death.

### 2026-10-20 — Kaplan-Meier cubes exported with the approved floor of 1

- `min_subject = 1` is approved for PCX. `counts_kaplan.workflow` sets it on both cubes and is
  the only Kaplan-Meier workflow; `counts_kaplan_site.workflow` and its `_site` cubes are gone.
- `stage/counts_kaplan.py` checks the workflow with the builder's site-only rules (any explicit
  positive floor with a description), because its shared rules require at least 10.

### 2026-10-20 — Kaplan-Meier source is plain SQL, no site column

- `sql/custom/kaplan_subject.sql.jinja` is now `sql/custom/pcx__kaplan_subject.sql`, run as is
  from `sql/custom` like the other study SQL.
- The `site` column is gone from `pcx__kaplan_subject` and all four cubes. The aggregator adds
  site when it combines each site's export. `HOME_INSTITUTION_CODE` is removed from
  `_settings.py`, the CHOP release script and cumulus-study.md.

### 2026-10-20 — LLM dates parsed once, unreadable dates flagged

- The eligible stage failed on Athena: `CAST(therapy_start_date AS DATE)` met `2020-09`.
  Real BCH values also include `2012-04`, `202?-05-23` and `10-30`.
- `sql/template/date_macros.sql.jinja`: every LLM wide table now adds `<name>_day` (DATE) and
  `<name>_day_precision` next to each date. Only `YYYY-MM-DD`, `YYYY-MM` and `YYYY` are
  understood, as the first day of the period, with the coarser of the shape and the stated
  precision. Other text gets NULL, and so does a day not on the calendar such as `2024-02-30`
  (seen in the BCH event results). The calendar check is string tests only, so it cannot error.
- `eligible_*`, `outcome_*`, `client_timeline` and the warn tables read `<name>_day` instead
  of casting the text. `client_timeline.date_precision` is the parsed precision, and a date
  that cannot be understood falls back to the note date (`date_type = documented`).
- New `pcx__warn_llm_date_invalid` lists every unreadable LLM date, all 44 date columns.
  `pcx__warn_llm_date_coarse` uses the parsed precision.
- Tests: `tests/test_llm_dates.py`, fixture columns and seeded bad dates (p1, p8).
  `tests/sqltest.py` gives DuckDB a `from_iso8601_timestamp` macro for `outcome_vital_status.sql`.

### 2026-10-19 — Kaplan-Meier count cubes

- New opt-in `counts_kaplan` stage: `pcx__kaplan_subject`, then OS and EFS cubes with
  the exact PCX-30 `_cube.csv` columns. `counts_kaplan.workflow` is shared (floor 10, exported),
  `counts_kaplan_site.workflow` is site-only (floor 1, never exported).
- `HOME_INSTITUTION_CODE` (default BCH) fills the `site` column. The CHOP release sets it to CHOP.
- Tests: `tests/test_counts_kaplan.py`. Dictionary rows added, PROTOCOL 8.1 updated.

### 2026-10-19 — outcome_vital_status parses FHIR deceasedDateTime

- `outcome_vital_status.sql`: `DATE(FROM_ISO8601_TIMESTAMP(deceasedDateTime))` instead of
  `DATE(deceasedDateTime)`, which failed the outcome stage on full timestamps like
  `2024-08-25T23:21:00Z`. Still a hard parse: malformed values error.

### 2026-10-16 — document_topic wide table reads versions 1 and 3

- `llm_document_topic_wide.sql.jinja`: UNION ALL of `task_version = 1` (no `survival_timeline`
  topic, columns NULL) and `task_version = 3` (`survival_timeline` read through JSON, NULL
  until a version 3 run adds the field to the table). Versions are hardcoded, not taken
  from the workflow. Existing BCH results are version 1 (42,060 rows). (Corrected 2026-10-21:
  BCH's table is version 2, 180,226 notes, and the table only ever holds one version.)
- `nlp_document_tasks.workflow`: `document_topic` version 3, so new runs land in the
  version 3 branch. `llm.md` lists the new version.

### 2026-10-16 — version 0.4.1

- `pyproject.toml` version 0.4.1 for the CHOP build, so its wheel is not confused with the
  0.4.0 wheel CHOP already has.

### 2026-10-16 — builder is a dev extra

- `pyproject.toml`: cumulus-study-builder moved to the `dev` extra, pinned to tag v0.5.7 over
  SSH (the repository is private). Install with `pip install -e ".[dev]"`.

### 2026-10-16 — CHOP release script

- New `release/make_chop_release.py`, a copy of `release/make_data_release.py` (unchanged) for CHOP. PRE: the study build
  runs with `HOME_INSTITUTION` set to Children's Hospital of Philadelphia, so the
  `transition_of_care` schemas name CHOP; the check fails if a released schema names Boston
  Children's Hospital. POST: the released `casedef.toml` runs
  `sql/custom/pcx__cohort_casedef_include.sql` (CHOP) instead of the generated include.

### 2026-10-09 — this release is 0.4.0

- The release in progress is 0.4.0 (as in `pyproject.toml`); 0.4.1 is the planned patch
  release after it. Corrects "the next release is 0.4.1" below.

### 2026-10-09 — release outputs beside the script

- `release/make_data_release.py` writes `release/venv/`, `release/package/` and
  `release/dist/` beside itself instead of `build/release/`, and deletes those three at the
  start of every run, so there is no folder to remove by hand. The old `build/` folder is no
  longer used.

### 2026-10-09 — release ships the CHOP casedef include

- The release copies `sql/custom/pcx__cohort_casedef_include.sql` (the CHOP site version of the
  casedef include table) to the same path in the package, although no stage lists it
  (`UNLISTED_FILES` in the release script). The build check confirms it is in the wheel.

### 2026-10-09 — documents made consistent

- One builder version (0.5.6) and one Cumulus Library version (6.3.5) across the documents.
  The next release is 0.4.1. The release is described the same way everywhere: the whole
  manifest, every stage, one dependency (Cumulus Library).
- `eligible.md` and `rapid-elastic.md` brought up to date: no age restriction, the
  2026-09-30 prior-therapy rules, pharmacy dispenses, current SQL file names, the single
  `spreadsheet/query_topics/` folder, `cumulus-study build elastic_upload`.
- Counts of workflows, tasks, schemas and projections removed from the prose. References to
  `docs/source/` and to `query_topics_ppv/` and `query_topics_recall/` removed.

### 2026-10-09 — release requires Cumulus Library

- The released package's `pyproject.toml` requires Cumulus Library in the range this
  repository's `pyproject.toml` declares (`>=6.3.5,<6.4`, the first release whose allowlist has
  `pcx`), read by `library_requirement()` in the release script. The build check confirms the
  wheel's metadata carries it. Rebuild any release made before this change.

### 2026-10-09 — builder 0.5.6, version 0.4.0

- Requires cumulus-study-builder 0.5.6 (`>=0.5.6,<0.6`, git tag `v0.5.6`), in which plain study
  SQL runs from `sql/custom/`. `requirements-tested.txt`, the release script's `BUILDER` and
  `cumulus-study.md` point at 0.5.6. The 18 old `sql/generated/pcx__{eligible,outcome,client}*.sql`
  copies go after the next `cumulus-study build`. `pyproject.toml` version is 0.4.0.

### 2026-10-09 — release copies the study manifest

- The release's `manifest.toml` is the study's, copied as is: only the `../spreadsheet/` data
  dictionary path moves inside the package. Every stage ships with its `skip_by_default`, now
  including the opt-in `llm_schema` (`stage/llm_schema.py` is not released, so it cannot run
  from the package). `manifest_blocks()`, `write_manifest()`, `released_stages()` and
  `UNRELEASED_STAGES` are gone.
- The release check now loads the released manifest with Cumulus Library, as a site's build
  does, and requires every file a stage lists (Python builders excepted) to be in the package.

### 2026-10-09 — study SQL runs from sql/custom (needs the next builder)

- With the unreleased cumulus-study-builder change, the `eligible`, `outcome` and
  `client_views` TOMLs list `sql/custom/<file>.sql` directly instead of a copy in
  `sql/generated/`. `tests/sqltest.py` now reads `sql/custom/`. After rebuilding with that
  builder, delete the 18 old `sql/generated/pcx__{eligible,outcome,client}*.sql` copies.

### 2026-10-09 — release ships every stage

- `release/make_data_release.py` releases every stage of the study manifest except
  `llm_schema` (it runs Python; its schemas already ship), with `skip_by_default` exactly as in
  `stage/manifest.py`. `UNRELEASED_STAGES` replaces `RELEASED_STAGES` and `OPT_IN_STAGES`.
- `../tests/sql/custom/` (the `qa_athena` SQL) is packaged at `tests/sql/custom/`, beside
  `spreadsheet/`. The check that rejected SQL reading LLM or NLP tables is gone, since those
  stages now ship.

### 2026-10-09 — flat sql/custom/

- The 18 study SQL files moved from `sql/custom/eligible/`, `outcome/` and `client_views/`
  into `sql/custom/` itself. The empty `sql/custom/counts/` was removed. The `FILES` lists in
  `stage/eligible.py`, `outcome.py` and `client_views.py` name the files without a subfolder.

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
