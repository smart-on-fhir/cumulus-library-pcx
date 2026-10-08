# pcx migration

## PCX-specific changes

The original 21 coded variable inputs, 14 annotation models, four workflow files and 17 count outputs are retained. The 23 NLP projections compile and execute against synthetic rows shaped by the actual JSON schemas. All 14 generated JSON schemas match the originals.

Eligibility, surgery/radiation/medication evidence, trial intersection, vital status, first event, exposure timing, client exports and QA/WARN SQL remain study-owned. The inherited clinical tests are ported. `HOME_INSTITUTION` now resolves from the local model settings instead of importing the original PCX package. The laboratory projection's ambiguous `result` alias is renamed without changing selected fields.

Document projection now precedes the clinical workflow in the optional pipeline. Full workflows are explicitly available. The two `_50k` variants were removed 2026-10-08. Both prompt text and versions are unchanged.

## Items requiring study/site review

- **Note selectors are an inherited gap.** Every workflow references `pcx__llm_document_task_<task>`, but the original repository never created these tables. `[builder] external_tables` in `cumulus-study.toml` lists them as external prerequisites (the document tasks no longer need one: they select from `pcx__sample_task`). Define or supply clinically reviewed selectors before running NLP. This migration does not invent a routing policy, silently process every note, or claim the NLP pipeline is ready without those selectors.
- Full diagnosis workflow/version **2** and limited workflow/version **3** differ. The full projections intentionally consume version 2, preserving the original projection contract. Running only the limited workflow does not satisfy all full clinical inputs. Resolve this as a versioned study decision before production.
- OS/EFS limitations, the coded case cohort versus trial-like eligibility distinction, and uncomputable trial criteria remain as documented in `LIMITATIONS.md` and `eligible.md`.
- Raw FHIR Patient deceased fields and MedicationDispense resources remain site prerequisites.

Data package version: **1 → 2**. Existing flat client CSV exports are retained; no new statistical estimand is introduced.

## Shared migration contract

- The make-pcx version is git tag `0.2-pre-study-builder` of this repository; the backport replaced it on branch `andy/study-builder` (2026-10-02). The tag is the record of the source files; the backport was taken from them as of 2026-09-19.
- Shared stages and tools come from cumulus-study-builder **0.5.5**, not copies in the study. Researcher-owned SQL stays in `sql/custom`, overrides of builder Jinja templates in `sql/template`, and generated SQL in `sql/generated`, all inside the study package `cumulus_library_pcx/`.
- Existing study prefixes, clinical code membership and authored clinical SQL are retained except for the explicit changes documented here. CSV metadata header corrections do not change any code/system rows.
- Current builder population/encounter handling applies: date fallback can attach evidence whose explicit encounter link is absent, encounters can have no end date, subject identity is checked on evidence joins, and note limits rank distinct subject/note pairs. Results are not claimed patient-for-patient equivalent to the older builder.
- Coded evidence tables retain raw links and selected links. Count adapters join demographics from the encounter spine where required; count table names, dimensions and floors are explicit in `counts.workflow` (the shared `counts` stage since 2026-09-22; the original `cubes.json` is retired). The workflow sits at the package root next to `manifest.toml`.
- NLP and dependent analysis stages are opt-in for warehouse execution. Local generation still prepares them all. There are no fake empty NLP result tables and no automatic inference, warehouse execution or patient export during generation.
- Skills come from the builder with `cumulus-study skills sync` into `.agents/skills`; starter-managed files are tracked with `cumulus-study starter sync`. Existing clinical source decisions take precedence over the starter's defaults; unused demo eligibility/outcome stages were not copied.
- `tests/column_contracts.json` declares expected external FHIR interfaces. Local column checks validate generated study dependencies against that interface; they cannot certify a site's actual warehouse schema.

## Validation and maintenance

Run `cumulus-study skills check`, `cumulus-study starter check`, `cumulus-study validate`, `cumulus-study build`, then `python -m pytest -q` from this checkout. The suite includes all-stage and default-stage SQL dependency/column checks, Cumulus manifest parsing and repeat-build checks.

`requirements-tested.txt` records the last passing run (cumulus-study-builder 0.5.5, cumulus-library 6.3.4, 2026-10-08); use it as constraints. Regenerate before accepting changed CSV or schema contracts.

## Moving to 0.5.0 (done 2026-10-02)

The study package moved from `study/` to `cumulus_library_pcx/` (`[study] directory` in
`cumulus-study.toml`); `pyproject.toml` pins `cumulus-study-builder>=0.5.0,<0.6` and
`cumulus-library>=6.3.4,<6.4` and packages `cumulus_library_pcx*`; `.gitignore` names the new
package; `counts.workflow` sits at the package root; `Stage(fhir_resource)` and the commented
biostats demo are gone; `cumulus-study starter sync` renamed the starter record to
`.cumulus-starter-sha256.json`; the tests import `cumulus_library_pcx`. `skills check`,
`starter check`, `build`, `validate` and pytest pass (71 tests).
