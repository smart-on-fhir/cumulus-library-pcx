# Workplan: cumulus-library-pcx (prefix `pcx`)

Open, study-specific work only, on cumulus-study-builder **0.5.0**, the git tag `v0.5.0` (not on
PyPI). Install it from `smart-on-fhir` with
`pip install "git+ssh://git@github.com/smart-on-fhir/cumulus-study-builder.git@v0.5.0"`, then
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

Runs on 0.5.0 with the `cumulus_library_pcx/` package (validated 2026-10-02 against the
`v0.5.0` tag: `skills check`, `starter check`, build, validate, 73 tests).

Next deliverable: publish PCX 0.3.0 to PyPI as a **built-artifact-only** package: rendered
SQL, TOML and JSON with no Python code and no dependencies, built from the builder tag
(DevOps, 2026-10-02). Since 2026-10-07 it also ships the NLP stages, because CHOP must run
the LLM on its own notes (no PHI leaves the site; CHOP has the Cumulus core tables and AWS
Bedrock). Cumulus Library runs the LLM from the released workflow files, so neither CHOP nor
the package needs cumulus-study-builder. See the release items under Build, tests and docs.

## Open questions

- [ ] **Allowlist name.** Cumulus Library's allowlist maps study `cancer_mtx` to the module
  `cumulus_library_pcx`; the planned allowlist PR renames it to `pcx`. Cumulus Library 6.3.4
  discovery (`cli.get_study_dict`) imports allowlisted modules and keys them by the manifest
  prefix, so the installed release should build as `-t pcx` without `--study-dir`. Read in
  the code, not yet run: the deferred release smoke test (below) confirms it.
- [ ] **Stock Cumulus Library runs the NLP stages.** Cumulus Library 6.3.4 has an NLP runner
  with a Bedrock provider (`--nlp-provider bedrock`, `--nlp-model`) and PCX's NLP stages are
  `config_type = "nlp"` workflows plus JSON schemas. Read in the installed package, not yet
  run: the release smoke test (below) confirms it. If it fails, the stopgap is a source
  install of PCX and the builder at CHOP. A builder dependency in the package needs the
  builder on PyPI first.
- [ ] **CHOP note selection.** The NLP workflows select notes from the 14 site-supplied
  `pcx__llm_document_task_*` tables (`external_tables` in `cumulus-study.toml`), which no
  stage builds. At BCH they come from the Elasticsearch queries. Decide how CHOP builds them.
- [ ] **CHOP model.** The rendered wide SQL reads `pcx__nlp_<task>_gpt_oss_120b`
  (`nlp_deployments` in `cumulus-study.toml`). CHOP must run `gpt-oss-120b` on Bedrock, or
  the release is rendered for the model CHOP runs.
- [ ] **Stages beyond NLP.** Decide whether the release also ships `eligible`, `outcome`,
  `client_views`, `qa_athena` and the `_50k` workflows, which read the LLM tables.
- [ ] **Diagnosis version.** Recommended: set the full workflow to version 3 and regenerate;
  version-2 rows already in a warehouse are then excluded ([§5](PROTOCOL.md#5-clinical-notes)).
- [ ] `reviews/` was not migrated: restore or record as dropped
  ([§5](PROTOCOL.md#5-clinical-notes)). The query topics are restored, as one `<topic>.txt`
  per topic in `spreadsheet/query_topics_ppv/` and `query_topics_recall/`.
- [ ] Inherited items 1.7, 1.8, 2.3–2.7, 3.4, 3.5 of `docs/source/workplan.md` cited in
  [§9](PROTOCOL.md#9-open-questions): keep, schedule or close.

## Objective

No changes planned.

## Population

No changes planned.

## Variables

- [ ] P2 · `study_variable` · Deduplicate `dx_methotrexate_toxic.csv`.

## Case definition

No changes planned.

## Clinical notes

- [ ] P1 · `nlp_clinical_tasks` · **One diagnosis task version.** `cumulus_library_pcx/nlp_clinical_tasks.workflow:43`
  says 2 and `cumulus_library_pcx/nlp_clinical_tasks_50k.workflow:44` says 3 for the same schema (the v3 shape), so
  the projection drops 50k results. Apply the decision above. *Done when* a test fails
  whenever two workflows defining a task disagree with the projection.

## Eligibility

- [ ] P3 · `eligible` · `t0_source` is `'casedef_tier1_medulloblastoma'` even when `t0_day`
  is NULL (`eligible_dx.sql:59`); the header says tiers 2 and 3 (`eligible_dx.sql:6`),
  casedef has tiers 1-2.

## Outcomes

No changes planned.

## Analysis

- [ ] P2 · `client_views` · **Client views.** `client_timeline.sql` joins on encounter only;
  notes with conflicting dates get a NULL `note_author_date` and drop out of
  `client_diagnosis.sql`. The `_50k` stages run after `client_views` (`cumulus_library_pcx/stage/manifest.py:20-22`).
- [ ] P3 · `client_views` · **Use the builder's client views.** The builder's opt-in
  `client_views` stage has templates for `client_subject`, `client_encounter`,
  `client_timeline`, `client_timeline_latest`, `client_dictionary_coverage` and
  `client_timeline_events`; keep only `client_diagnosis`, `client_exposure`, `client_outcome`
  and overrides in `cumulus_library_pcx/sql/custom/client_views/` (builder rank 17). *Done when* the client
  tables and `spreadsheet/client_dictionary.csv` columns are unchanged.

## Build, tests and docs

- [ ] P1 · release · **Add the NLP stages to the release script.** `release/make_data_release.py`
  assembles only the seven default stages and rejects anything else. Add `nlp_document_tasks`,
  `llm_document_wide`, `nlp_clinical_tasks` and `llm_clinical_wide`, still opt-in: their
  guard TOMLs, the `.workflow` files, the JSON schemas they name (`llm/schemas/`),
  `nlp-selection-requirements.json` and the wide SQL. Leave out `llm_schema`, the only stage
  that runs Python (the schemas ship already built), and `elastic_upload`. The check that
  rejects SQL reading LLM or NLP tables becomes: no Python but `__init__.py`, and every file a
  stage names is in the package. *Done when* the wheel holds those stages and no Python.
- [ ] P1 · release · **Release smoke test** (was deferred 2026-10-05; now gates the release).
  A clean venv with only Cumulus Library installs the wheel. `cumulus-library build -t pcx`
  runs the seven default stages on DuckDB, and one NLP stage runs against Bedrock on
  synthetic notes. Needs the core tables and the site tables the stages read
  (`tests/column_contracts.json`), with or without rows. Settles the allowlist and
  stock-Cumulus-Library questions above.
- [ ] P1 · release · **Publish 0.3.0 to PyPI** (DevOps, 2026-10-02), after the two items
  above. The script makes a venv with the builder tag and the tested pins, renders,
  assembles, checks and builds the wheel and sdist into `build/release/dist/`
  ([README](README.md#release)). Publishing stays manual: Andy or @msa2984 runs the printed
  `twine upload` straight to PyPI (no TestPyPI), from `andy/study-builder` before the PR
  merges, then tags the release commit `v0.3.0`. *Done when* 0.3.0 is on PyPI and tagged.
- [ ] P3 · release · Optionally, a dispatchable GitHub Action that calls the script. It needs
  read access to the builder repository and a PyPI token or trusted publishing.
- [ ] P2 · tests · **Default plan test.** Assert `StudyManifest.get_stage('all')` contains none
  of the 11 opt-in actions, including with synthetic Elastic inputs.
- [ ] P3 · `qa_athena` · Optionally replace the study-owned `qa_athena` stage with the shared
  `Stage(qa)`.
