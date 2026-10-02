# pcx migration

## PCX-specific changes

The original 21 coded variable inputs, 14 annotation models, four workflow files and 17 count outputs are retained. The 23 NLP projections compile and execute against synthetic rows shaped by the actual JSON schemas. All 14 generated JSON schemas match the originals.

Eligibility, surgery/radiation/medication evidence, trial intersection, vital status, first event, exposure timing, client exports and QA/WARN SQL remain study-owned. The inherited clinical tests are ported. `HOME_INSTITUTION` now resolves from the local model settings instead of importing the original PCX package. The laboratory projection's ambiguous `result` alias is renamed without changing selected fields.

Document projection now precedes the clinical workflow in the optional pipeline. Full workflows are explicitly available; the two `_50k` variants remain opt-in alternatives. Both prompt text and versions are unchanged.

## Items requiring study/site review

- **Note selectors are an inherited gap.** Every workflow references `pcx__llm_document_task_<task>`, but the original repository never created these tables. `study/nlp-selection-requirements.json` lists them as external prerequisites. Define or supply clinically reviewed selectors before running NLP. This migration does not invent a routing policy, silently process every note, or claim the NLP pipeline is ready without those selectors.
- Full diagnosis workflow/version **2** and limited workflow/version **3** differ. The full projections intentionally consume version 2, preserving the original projection contract. Running only the limited workflow does not satisfy all full clinical inputs. Resolve this as a versioned study decision before production.
- OS/EFS limitations, the coded case cohort versus trial-like eligibility distinction, and uncomputable trial criteria remain as documented in `docs/source/limitations.md` and `eligible.md`.
- Raw FHIR Patient deceased fields and MedicationDispense resources remain site prerequisites.

Data package version: **1 → 2**. Existing flat client CSV exports are retained; no new statistical estimand is introduced.

## Shared migration contract

- The original repository is unchanged. `docs/source_inventory.json` records source file hashes; `tests/legacy_contract.json` pins migrated input, workflow, schema and count-output contracts.
- Shared stages and tools come from cumulus-study-builder (docs target **0.5.0**), not copies in the study. Researcher-owned SQL stays in `sql/custom`, overrides of builder Jinja templates in `sql/template`, and generated SQL in `sql/generated`, all inside the study package (`study/` today, `cumulus_library_pcx/` after the move).
- Existing study prefixes, clinical code membership and authored clinical SQL are retained except for the explicit changes documented here. CSV metadata header corrections do not change any code/system rows.
- Current builder population/encounter handling applies: date fallback can attach evidence whose explicit encounter link is absent, encounters can have no end date, subject identity is checked on evidence joins, and note limits rank distinct subject/note pairs. Results are not claimed patient-for-patient equivalent to the older builder.
- Coded evidence tables retain raw links and selected links. Count adapters join demographics from the encounter spine where required; count table names, dimensions and floors are explicit in `counts.workflow` (the shared `counts` stage since 2026-09-22; the original `study/cubes.json` is retired). On 0.5.0 the workflow sits at the package root next to `manifest.toml`.
- NLP and dependent analysis stages are opt-in for warehouse execution. Local generation still prepares them all. There are no fake empty NLP result tables and no automatic inference, warehouse execution or patient export during generation.
- Skills come from the builder with `cumulus-study skills sync` into `.agents/skills`; starter-managed files are tracked with `cumulus-study starter sync`. Existing clinical source decisions take precedence over the starter's defaults; unused demo eligibility/outcome stages were not copied.
- `tests/column_contracts.json` declares expected external FHIR interfaces. Local column checks validate generated study dependencies against that interface; they cannot certify a site's actual warehouse schema.

## Validation and maintenance

Run `cumulus-study skills check`, `cumulus-study starter check`, `cumulus-study validate`, `cumulus-study build`, then `python -m pytest -q` from this checkout. The suite includes all-stage and default-stage SQL dependency/column checks, Cumulus manifest parsing and repeat-build checks.

`requirements-tested.txt` records the last passing run (cumulus-study-builder 0.4.1, cumulus-library 6.3.2, 2026-09-22); use it as constraints and refresh it after the 0.5.0 move. Regenerate before accepting changed CSV or schema contracts.

## Moving to 0.5.0

The general renames are in the builder's MIGRATION.md (section 0.5.0). For this study:

1. Move `study/` to `cumulus_library_pcx/`; set `[study] directory = "cumulus_library_pcx"` in `cumulus-study.toml`.
2. `pyproject.toml`: pin `cumulus-study-builder>=0.5.0,<0.6`, drop the `biostats` extra, `packages.find` `where = ["."]`, `include = ["cumulus_library_pcx*"]`.
3. Repoint the `study/` and `analysis/` lines of `.gitignore`.
4. Move `sql/custom/counts/counts.workflow` to the package root next to `manifest.toml`.
5. Run `cumulus-study starter sync` (renames the old starter record to `.cumulus-starter-sha256.json`).
6. Remove the commented biostats demo (`analysis/exports.toml`, `stage/biostats.py`, `sql/custom/biostats/`); `spreadsheet/data_dictionary.csv` stays as Cumulus Library's dictionary.
7. Fix the tests' `study` imports and `sys.path` insert (`conftest.py`, `test_llm_models.py`, `test_counts.py`) and doc paths, then run the checks above.
