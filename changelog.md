# Changelog

## 2026-10-08 — cumulus-study.md, README as a table of contents

- `docs/source/make-pcx.md` is replaced by `cumulus-study.md` at the repository root: set up,
  commands, the stage list, settings, environment, inputs and outputs, and the release,
  written for `cumulus-study`. The `make-pcx` manual is in git history.
- README.md is now a short table of contents. Its set up, edit, warehouse and release
  sections moved to `cumulus-study.md`.

## 2026-10-08 — LIMITATIONS.md at the repository root

- `docs/source/limitations.md` moved to `LIMITATIONS.md`. The dated "Current implementation
  findings (2026-09-11)" list is removed: most of it was fixed by the builder move and the
  2026-09-30 eligibility decisions, and what is still open is in WORKPLAN.md. Sentences in
  sections 1, 4, 5, 6 and 7 that described fixed defects are corrected.

## 2026-10-08 — Cumulus Library 6.3.5 allowlists pcx

- Cumulus Library 6.3.5 lists `"pcx": "cumulus_library_pcx"` in its module allowlist. The
  first 0.4.0 item in WORKPLAN is done. Moving the study's own pins to 6.3.5 is a new open item.

## 2026-10-08 — LLM.md at the repository root

- `docs/source/llm.md` moved to `LLM.md` and brought up to date: 12 clinical tasks with
  their current versions, `diagnosis` in place of the removed `medulloblastoma` model, no
  `_50k` workflows, a note-selection section, and `cumulus-study build` in place of
  `make-pcx`. Resolved integration gaps and dead links to `reviews/` were cut.

## 2026-10-08 — old workplan removed

- `docs/source/workplan.md` (2026-09-11) is removed. Its 21 still-open items are now in
  WORKPLAN.md under their sections, marked "(was N.N)", plus four listed as not re-checked. Done
  and superseded items were dropped. PROTOCOL and the other `docs/source` notes no longer cite its item numbers.

## 2026-10-08 — builder 0.5.5, selector guards removed

- The study requires cumulus-study-builder `>=0.5.5,<0.6` and installs the `v0.5.5` tag.
- The NLP selector guards are gone: no `nlp_<workflow>_guard.toml`, no
  `pcx__qa_selector_<workflow>.sql`, and each workflow is one entry in `manifest.toml`.
- An empty selector table now sends every note to the LLM. `pcx__sample_task` always has
  rows. The 12 clinical selectors must be checked by hand before `nlp_clinical_tasks` runs.

## 2026-10-08 — plan for release 0.4.0

- WORKPLAN has a "Release 0.4.0" section: the first LLM workflow, scoped to
  `document_type` and `document_topic` in `nlp_document_tasks.workflow`, with the ordered
  work to get there. PROTOCOL records the scope. Docs only.

## 2026-10-08 — release plan for 0.3.0

- 0.3.0 ships the eight default stages on builder 0.5.4. The NLP stages and the release smoke
  test move to the following release.
- Decided: CHOP runs `gpt-oss-120b`, and each clinical task will select the notes the LLM
  marked relevant to its topic. WORKPLAN and PROTOCOL record both.

## 2026-10-08 — document tasks select from pcx__sample_task

- `nlp_document_tasks.workflow` selects its notes from `pcx__sample_task` (casedef notes plus
  Elasticsearch notes), so the document tasks need no site-supplied table. The two
  `pcx__llm_document_task_document_*` names left `external_tables`.
- Both `_50k` workflows and their stages are removed. The document one was a copy of
  `nlp_document_tasks.workflow`.
- Removed `cumulus_library_pcx/nlp-selection-requirements.json`: it repeated the
  `external_tables` list in `cumulus-study.toml`, which is now the one place for it.

## 2026-10-08 — builder 0.5.4, pcx__sample_task

- The study requires cumulus-study-builder `>=0.5.4,<0.6` and installs the `v0.5.4` tag.
- New table `pcx__sample_task`, built by the `sample` stage: every casedef note (topic
  `casedef`) plus every Elasticsearch note (its search topic). A note appears once per topic.

## 2026-10-08 — elastic_upload is a default stage

- `elastic_upload` runs by default, before `sample`, so every site has `pcx__elastic_union`:
  empty at a site with no Elasticsearch export (CHOP), the uploaded results at a site with one.
  A default build at a site with an export now uploads its CSVs.
- `llm_schema` is opt-in. The default plan is eight stages with no Python.
- The release script ships `elastic_upload` and renders without an export, so the released
  union is the empty table.

## 2026-10-08 — builder 0.5.3

- The study requires cumulus-study-builder `>=0.5.3,<0.6` and installs the `v0.5.3` tag.
  The `elastic_upload` stage now always builds `pcx__elastic_union`: empty, with the same
  columns, when there are no export CSVs.

## 2026-10-08 — builder 0.5.2

- The study requires cumulus-study-builder `>=0.5.2,<0.6` and installs the `v0.5.2` tag
  (release script, README, WORKPLAN, `requirements-tested.txt`). 0.5.1 reads the query-topic
  folder. 0.5.2 fixes `cumulus-study build` stopping once the Elasticsearch export holds CSVs.

## 2026-10-08 — query topics in the rapid-elastic format

- Query topics are one `<topic>.txt` per topic (file name is the topic, text is the query):
  `spreadsheet/query_topics_ppv/` and `query_topics_recall/`, 17 topics each, with
  `spreadsheet/query_topics` a symlink to the PPV folder. The queries are unchanged from the
  TSVs, which are removed. `docs/source/query_topics.md`, PROTOCOL and WORKPLAN updated.

## 2026-10-07 — release plan: data-only, with NLP stages

- WORKPLAN: the PyPI release stays data-only (SQL, TOML, JSON) and now includes the NLP
  stages, so CHOP can run the LLM locally with stock Cumulus Library. New release items
  (script, smoke test) and open questions (CHOP note selection, model, further stages).
  PROTOCOL records the decision. Docs only: the release script is unchanged.

## 2026-10-07 — builder repository is smart-on-fhir

- The builder install URL is now `smart-on-fhir/cumulus-study-builder` (was `comorbidity/`)
  in the release script, README and WORKPLAN. Tag `v0.5.0` is the same commit there.

## 2026-10-07 — migration scaffolding removed

- PCX has no released version to migrate from, so the migration pins are gone: Andy deleted
  `tests/legacy_contract.json` and `docs/source_inventory.json`. The old repo is kept as git
  tag `0.2-pre-study-builder`. `spreadsheet/README.md`, MIGRATION and PROTOCOL no longer cite
  the deleted files.
- `tests/test_migration.py` is now `tests/test_stage_sql.py`. Kept: inputs validate, the
  stage-order SQL column check, the repeat-build check. Removed: the CSV, schema, workflow
  and count-table pins. Site-supplied tables come from `external_tables` in
  `cumulus-study.toml`.

## 2026-10-06 — release script uses filetool

- `release/make_data_release.py` finds the repository, the study package and the spreadsheet
  folder with the builder's `filetool` (`path_root`, `path_project`, `path_spreadsheet`), not
  `Path(__file__).parents[1]`. It now has to run from a Python with cumulus-study-builder
  installed (the development venv). README Release section says so.

## 2026-10-05 — data-only release script

- New `release/make_data_release.py` builds the data-only PyPI package: a venv with the
  builder tag, render and validate, then the seven default stages without NLP assembled into
  `build/release/package/` (`../spreadsheet/` paths moved inside the package), checked (no
  Python but `__init__.py`, no LLM or NLP tables) and built with flit into
  `build/release/dist/`. It prints the `twine upload` command and never uploads.
- README has a Release section. PROTOCOL and WORKPLAN record the release decisions: no
  TestPyPI, release from the branch, smoke test deferred.

## 2026-10-05 — medications from core, eligibility flags, ages 0-120

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

## 2026-10-02 — builder from the v0.5.0 tag; version 0.3.0

- Setup installs cumulus-study-builder from its `v0.5.0` git tag (`git+ssh`, comorbidity
  repository). Re-validated against the tag: skills check, starter check, build, validate,
  70 tests.
- Removed `test_schema_generation_writes_one_schema_per_task`: the tag refuses schema writes
  outside the study, and `test_migration.py` already checks every built schema's hash.
- Removed `tests/data/synthetic`, which no test reads.
- Version 0.3.0 for the first data-only PyPI release (default stages without NLP). The plan
  is in WORKPLAN.md.

## 2026-10-02 — study-builder version replaces make-pcx; builder 0.5.0

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

## 2026-09-24 — builder 0.5.0 inputs and docs

- WORKPLAN.md, PROTOCOL.md and MIGRATION.md now target cumulus-study-builder 0.5.0 after a
  code review; the code move itself is the P1 item in WORKPLAN.md.
- Removed `spreadsheet/include_diag_category.csv`: builder 0.5.0 no longer reads it and carries
  the same six report-category labels itself. Its hash left `tests/legacy_contract.json`.
- The builder's biostats module is not used outside IBD: the demo biostats scaffold is to be
  removed in the 0.5.0 move, not converted.

## 2026-09-22 — builder 0.4.1 release candidate

- Checked against the final cumulus-study-builder 0.4.1 candidate and cumulus-study-template
  v0.4.1: skills sync, template sync, validate, build and tests pass. `AGENTS.md` now points
  study-specific agent rules to a new `Agent rules` section at the end of `PROTOCOL.md`.

## 2026-09-22 — workplan by protocol section

- `WORKPLAN.md` headings are now the plain PROTOCOL.md section names (no numbers), every section listed ("No changes planned." when empty), Open questions first and Build, tests and docs last; the Summary heading was dropped, its text kept as the intro.
- `WORKPLAN.md` regrouped under the `PROTOCOL.md` section headings (plus Build, tests and docs);
  each entry tagged with priority and stage, decisions moved to the top. No tasks added or dropped.

## 2026-09-22 — workplan section titles

- `WORKPLAN.md`: P1, P2 and P3 items grouped under short titled headings (e.g. `P1 · Trial
  cohort eligibility`); a priority can now have several sections. No items changed.

## 2026-09-22 — workplan for builder 0.4.1

- `WORKPLAN.md` rewritten: open study work only, assuming cumulus-study-builder 0.4.1 and
  cumulus-study-template v0.4.1, under Summary / P1 / P2 / P3 / Decisions with links to
  `PROTOCOL.md`. Superseded workplans and reviews moved to `_to_delete/`.
- `pyproject.toml` requires `cumulus-library>=6.3.2,<6.4` (was `==6.3.1`), as builder 0.4.1 needs.
- Adopted builder 0.4.1: `tests/test_migration.py` reads upload `files` (falling back to `file`);
  `tests/column_contracts.json` drops `core__encounter.class_system`, adds `information_schema.columns`, adds `core__condition.category_system`/`category_display`
  and the DiagnosticReport `conclusioncode_*` columns; skills re-synced; validate, build and
  pytest pass on cumulus-library 6.3.2; `requirements-tested.txt` updated.

## 2026-09-22 — template sync adopted

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

## 2026-09-21 — re-aligned with the current builder and template

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

## 2026-09-19 — builder backport

- Migrated from `cumulus-library-pcx` to cumulus-study-builder 0.4.0 and the study-template layout (prefix `pcx`, data package version 1 -> 2).
- 21 coded variables, 14 annotation models, four workflows, 23 NLP projections, eligibility, outcomes, client exports, QA and 17 count outputs retained; `HOME_INSTITUTION` resolves from local settings.
- Reviewed 2026-09-19: see CODE_REVIEW.md.
