# Workplan: cumulus-library-pcx (prefix `pcx`)

Open, study-specific work only, on cumulus-study-builder **0.5.0**, the git tag `v0.5.0` (not on
PyPI). Until the builder repository moves to `smart-on-fhir`, install it with
`pip install "git+ssh://git@github.com/comorbidity/cumulus-study-builder.git@v0.5.0"`, then
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

Next deliverable (DevOps, 2026-10-02): publish PCX 0.3.0 to PyPI as a **built-artifact-only**
package, rendered SQL and data with no Python dependencies, built from the builder tag. It
ships the default stages without NLP; see "Data-only PyPI release" under Build, tests and docs.

## Open questions

- [ ] **Where the release workflow runs**: a local script, a dispatchable GitHub Action, or
  both (the Action calls the script). PyPI publish rights: the DevOps lead and @msa2984.
- [ ] **Allowlist name.** Cumulus Library's allowlist maps study `cancer_mtx` to the module
  `cumulus_library_pcx`; the planned allowlist PR renames it to `pcx`. Discovery finds
  allowlisted modules and keys them by the manifest prefix, so an installed release may
  already build as `-t pcx` without `--study-dir`: the release smoke test settles it.
- [ ] **Diagnosis version.** Recommended: set the full workflow to version 3 and regenerate;
  version-2 rows already in a warehouse are then excluded ([§5](PROTOCOL.md#5-clinical-notes)).
- [ ] Note-selection inputs (query-topic TSVs and `reviews/`) were not migrated: restore or
  record as dropped ([§5](PROTOCOL.md#5-clinical-notes)).
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

- [ ] P1 · release · **Data-only PyPI release** (DevOps, 2026-10-02). A release workflow, local or a dispatchable GitHub Action:
  1. Make an isolated venv with Cumulus Library, the builder tag and PCX installed.
  2. Run `cumulus-study build` to render the artifacts.
  3. Copy into a standalone directory: `manifest.toml`, the stage TOMLs, the rendered
     `sql/generated/` SQL and workflows (including counts), and the data files
     (`spreadsheet/` CSVs and `file_upload_*.toml`, `data_dictionary.csv`). Add a minimal
     `pyproject.toml` with no dependencies and an `__init__.py`. Rewrite paths that point
     outside the package (`manifest.toml` `data_dictionary = "../spreadsheet/..."`, the
     `../spreadsheet/file_upload_*.toml` references in the casedef, study_population and
     study_variable TOMLs).
  4. Keep only the released stages in `manifest.toml`: `study_population`, `study_variable`,
     `study_variable_wide`, `casedef`, `sample`, `counts`, `study_meta` (the default plan
     without `llm_schema`). The NLP stages go, and so do `eligible`, `outcome` and
     `client_views`, which read LLM tables, and the opt-in `qa_athena`. No `.py` file may
     remain in the package.
  5. Build, then publish to PyPI (the DevOps lead or @msa2984 holds the rights).
  Keep steps 1–4 separable from step 5: DevOps may reuse them for a future automated
  distribution (builder WORKPLAN, "Reusable render step"). The README states the
  Cumulus Library version the release was rendered and tested with.
  *Done when* `cumulus-library-pcx` 0.3.0 is on PyPI (TestPyPI first), the wheel holds no
  Python beyond `__init__.py`, a clean venv with only Cumulus Library installs it, and
  `cumulus-library build -t pcx` (with `--study-dir` only if the allowlist question above
  requires it) runs the seven stages on DuckDB. README and PROTOCOL then say how sites
  install the release.
- [ ] P2 · tests · **Default plan test.** Assert `StudyManifest.get_stage('all')` contains none
  of the 11 opt-in actions, including with synthetic Elastic inputs.
- [ ] P3 · `qa_athena` · Optionally replace the study-owned `qa_athena` stage with the shared
  `Stage(qa)`.
