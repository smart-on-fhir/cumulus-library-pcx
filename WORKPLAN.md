# Workplan: cumulus-library-pcx (prefix `pcx`)

Open, study-specific work only, assuming cumulus-study-builder **0.5.0**, installed from the
git tag `v0.5.0` (the builder is not on PyPI yet). Done work is in
[CHANGELOG.md](CHANGELOG.md).
Sections follow [PROTOCOL.md](PROTOCOL.md) (a section with nothing planned says so), then Build, tests and docs.
Each entry: priority · `stage` · task. Paths are as on disk today (`study/...`); after the
0.5.0 move they are under `cumulus_library_pcx/`.
**P1** before the next warehouse, export or NLP run (and the 0.5.0 move) · **P2** correctness or usability · **P3** cleanup.

Medulloblastoma (Group 3 first): do the ACNS0334 treatment-associated outcome differences
appear in EHR cohorts? The study builds a discovery cohort and a trial-like cohort
([§1](PROTOCOL.md#1-objective), [§6](PROTOCOL.md#6-eligibility)). The prior-therapy criteria
must be fixed before the trial cohort is used, the diagnosis task version before NLP results
are used ([§5](PROTOCOL.md#5-clinical-notes)); the treatment-effect analysis is not yet
specified ([§8](PROTOCOL.md#8-analysis)).

Runs on 0.4.1 with the `study/` package (validated 2026-09-22: validate, build, `skills check`,
71 tests); the 0.5.0 move is the P1 item under Build, tests and docs.

Next deliverable (DevOps, 2026-10-02): publish PCX to PyPI as a **built-artifact-only**
package, rendered SQL and data with no Python dependencies, built from the builder tag. NLP
stages are left out of this round. See "Data-only PyPI release" under Build, tests and docs.

## Open questions

- [ ] **What ships in the first data-only release.** DevOps: drop every NLP builder.
  That removes `llm_schema` (a Python builder), `elastic_upload`, the four `nlp_*` workflows
  and their guards, and `llm_document_wide` / `llm_clinical_wide`. `eligible`, `outcome`
  and `client_views` read LLM tables (`eligible*.sql`, `outcome_*.sql`,
  `client_diagnosis.sql`), so they go too unless rewritten. Proposed release:
  `study_population`, `study_variable`, `study_variable_wide`, `casedef`, `sample`,
  `counts`, `study_meta` (the default plan without NLP). Confirm `sample` and `qa_athena`.
- [ ] **Where the release workflow runs**: a local script, a dispatchable GitHub Action, or
  both (the Action calls the script). PyPI publish rights: the DevOps lead and @msa2984.
- [ ] **Release version and name.** `pyproject.toml` says 1.0.0. The PyPI name
  `cumulus-library-pcx`, import `cumulus_library_pcx`. Cumulus Library's allowlist lists the
  package as study `cancer_mtx`; the planned allowlist PR renames it to `pcx`. Until it
  merges, sites pass `--study-dir` to the installed package.
- [ ] **Prior-therapy observation policy.** "No prior chemotherapy/radiation" is TRUE today
  only when some chemotherapy/radiation evidence exists and none is dated before t0, so an
  ACNS0334-like child never irradiated is NULL and leaves `eligible_trial`. Decide what
  observation proves "no prior": e.g. t0 known, dated evidence only, and a documented
  lookback (encounter coverage alone is not enough). Recommended minimum: t0 NULL or any
  undated evidence → NULL ([§6](PROTOCOL.md#6-eligibility)).
- [ ] **Diagnosis version.** Recommended: set the full workflow to version 3 and regenerate;
  version-2 rows already in a warehouse are then excluded ([§5](PROTOCOL.md#5-clinical-notes)).
- [ ] Note-selection inputs (query-topic TSVs and `reviews/`) were not migrated: restore or
  record as dropped ([§5](PROTOCOL.md#5-clinical-notes)).
- [ ] Inherited items 1.7, 1.8, 2.1–2.7, 3.4, 3.5 of `docs/source/workplan.md` cited in
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

- [ ] P1 · `nlp_clinical_tasks` · **One diagnosis task version.** `study/nlp_clinical_tasks.workflow:43`
  says 2 and `study/nlp_clinical_tasks_50k.workflow:44` says 3 for the same schema (the v3 shape), so
  the projection drops 50k results. Apply the decision above. *Done when* a test fails
  whenever two workflows defining a task disagree with the projection.

## Eligibility

- [ ] P1 · `eligible` · **Unknown or undated prior therapy stays unknown.**
  `study/sql/custom/eligible/eligible.sql:34-44` returns TRUE whenever any evidence exists
  and `*_prior_to_t0_bool` is NULL. That happens when `t0_day` is NULL (LLM-only
  medulloblastoma, `eligible_dx.sql:58`) and when an LLM ADMINISTERED row has no date
  (`eligible_rx.sql:47,55,69`, `eligible_radiation.sql:28,38`); `eligible_trial.sql:7-14`
  has no t0 requirement. `llm_explicitly_not_received_bool` (`eligible.sql:42`) is not
  dated against t0. Apply the policy above. *Done when* `tests/test_eligible_outcome_sql.py`
  shows t0 NULL → both flags NULL and absent from `eligible_trial`; undated evidence → NULL;
  evidence before t0 → FALSE.
- [ ] P3 · `eligible` · `t0_source` is `'casedef_tier1_medulloblastoma'` even when `t0_day`
  is NULL (`eligible_dx.sql:59`); the header says tiers 2 and 3 (`eligible_dx.sql:6`),
  casedef has tiers 1-2.

## Outcomes

No changes planned.

## Analysis

- [ ] P2 · `client_views` · **Client views.** `client_timeline.sql` joins on encounter only;
  notes with conflicting dates get a NULL `note_author_date` and drop out of
  `client_diagnosis.sql`. The `_50k` stages run after `client_views` (`study/stage/manifest.py:24-26`).
- [ ] P3 · `client_views` · **Use the builder's client views.** The builder's opt-in
  `client_views` stage has templates for `client_subject`, `client_encounter`,
  `client_timeline`, `client_timeline_latest`, `client_dictionary_coverage` and
  `client_timeline_events`; keep only `client_diagnosis`, `client_exposure`, `client_outcome`
  and overrides in `study/sql/custom/client_views/` (builder rank 17). *Done when* the client
  tables and `spreadsheet/client_dictionary.csv` columns are unchanged.

## Build, tests and docs

- [ ] P1 · build · **Move to builder 0.5.0.** Move `study/` to `cumulus_library_pcx/` and set
  `[study] directory` (`cumulus-study.toml:2`); pin `cumulus-study-builder>=0.5.0,<0.6` and
  drop the `biostats` extra (`pyproject.toml:5,10`); `packages.find` `where = ["."]`,
  `include = ["cumulus_library_pcx*"]` (`pyproject.toml:17`); repoint `.gitignore:11-17`; move
  `study/sql/custom/counts/counts.workflow` to the package root (and the comment at
  `study/stage/manifest.py:28`); `starter sync` renames the starter record;
  remove the commented biostats demo (`analysis/exports.toml`, `study/stage/biostats.py`,
  `study/sql/custom/biostats/`; `spreadsheet/data_dictionary.csv` stays as Cumulus Library's
  dictionary, `study/manifest.toml:2`); fix the `study` imports and `sys.path` insert
  (`tests/conftest.py:8,19`, `tests/test_llm_models.py:6-13`, `tests/test_counts.py:12`);
  update doc paths (README, AGENTS, PROTOCOL, `analysis/README.md`). Remove
  `Stage(fhir_resource)`, which builder 0.5.0 drops; nothing here reads `pcx__medicationrequest`
  or `pcx__medicationdispense` (`study/stage/manifest.py:3,7`, `study/manifest.toml:4-8`,
  `study/fhir_resource.toml`, `PROTOCOL.md:33`). Pin `cumulus-library>=6.3.4,<6.4`
  (`pyproject.toml:5`; the builder requires it). The builder pin stays a version range:
  install the builder tag first (`pip install "git+https://github.com/smart-on-fhir/cumulus-study-builder@v0.5.0"`),
  then `pip install -e '.[test]'`; README setup says so. Then `cumulus-study skills sync` (the synced skills stop citing the
  builder's removed `fhir_resource` stage). No `[hooks]`, `[paths]` or removed `[builder]`
  keys to drop. *Done when* `skills check`, `starter check`, `validate`, `build` and pytest pass
  on 0.5.0 and `requirements-tested.txt` is refreshed.
- [ ] P1 · release · **Data-only PyPI release** (DevOps, 2026-10-02). After the 0.5.0
  move. A release workflow, local or a dispatchable GitHub Action:
  1. Make an isolated venv with Cumulus Library, the builder tag and PCX installed.
  2. Run `cumulus-study build` to render the artifacts.
  3. Copy into a standalone directory: `manifest.toml`, the stage TOMLs, the rendered
     `sql/generated/` SQL and workflows (including counts), and the data files
     (`spreadsheet/` CSVs and `file_upload_*.toml`, `data_dictionary.csv`). Add a minimal
     `pyproject.toml` with no dependencies and an `__init__.py`. Rewrite paths that point
     outside the package (`manifest.toml` `data_dictionary = "../spreadsheet/..."`, the
     `../../spreadsheet/` upload references).
  4. Remove the NLP stages, and anything that reads their tables, from `manifest.toml`
     (open question above). No `.py` file may remain in the package.
  5. Build, then publish to PyPI (the DevOps lead or @msa2984 holds the rights).
  Keep steps 1–4 separable from step 5: DevOps may reuse them for a future automated
  distribution (builder WORKPLAN, "Reusable render step"). The README states the
  Cumulus Library version the release was rendered and tested with.
  *Done when* the published wheel holds no Python beyond `__init__.py`, a clean venv with
  only Cumulus Library installs it, and `cumulus-library build -t pcx --study-dir
  <installed package>` runs the released stages on DuckDB.
- [ ] P2 · tests · **Default plan test.** Assert `StudyManifest.get_stage('all')` contains none
  of the 11 opt-in actions, including with synthetic Elastic inputs.
- [ ] P3 · `qa_athena` · Optionally replace the study-owned `qa_athena` stage with the shared
  `Stage(qa)`.
