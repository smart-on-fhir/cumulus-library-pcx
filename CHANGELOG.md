# Changelog

Short, human-readable notes on what changed and why. Newest first.

## 2026-10-02 (no empty synthetic test files)

- The synthetic generator no longer writes header-only CSVs for tables it
  leaves empty. The 7 `pcx__valueset_rx_*.csv` files and
  `core__medicationdispense.csv` in `tests/data/synthetic` go away. schema.sql
  still creates those tables (empty) because `pcx__eligible_rx` reads them.
- The dispense test is unchanged: it uses the 2 non-empty valueset fixtures
  in `tests/data/warn`.

## 2026-10-02 (.gitignore cleanup)

- `.gitignore` now ignores all of `cumulus_library_pcx/sql/generated`
  (was only `pcx__llm_*.sql`). Regenerate, do not commit.
- `.gitignore` also ignores `.DS_Store`, `__pycache__/`, `*~` editor backups
  and the `ve/` and `.venv/` virtualenvs.

## 2026-09-30 (relaxed eligibility: flags, not exclusions)

- PCX is broader than the ACNS0334 trial. Three criteria are now yes/no flags on
  `pcx__eligible` instead of exclusions: age under 36 months, prior methotrexate
  and prior radiation. Prior chemotherapy is a flag too.
- `pcx__eligible` gains `age_under_36_months_at_t0` (diagnosis) next to
  `age_under_36_months_at_definitive_surgery` (ACNS0334), plus
  `methotrexate_prior_to_t0_bool`, `chemo_prior_to_t0_bool` and
  `radiation_prior_to_t0_bool`. `no_prior_chemotherapy_bool` and
  `no_prior_radiation_bool` are removed.
- Prior flags are FALSE when t0 is known and nothing is dated before it, NULL
  only without a t0. The "ever" flags (`*_any_bool`) are FALSE when there is no
  evidence, never NULL. Closes workplan 2.1 and 2.2.
- `pcx__eligible_trial` stays strict, and prior methotrexate now excludes too
  (ACNS0334 excludes any prior chemotherapy). Subjects with a t0 and no
  treatment evidence are now in it, and subjects without a t0 are not.
- `study_population` keeps visits at ages 0-120 (was 0-8). `age_group.csv`
  covers every age: Adolescent, Young adult, Adult and Older adult bands were
  added.
- Downstream: `pcx__client_subject` carries the new flags,
  `pcx__client_exposure` reads `methotrexate_prior_to_t0_bool`, two warn tables
  are reworded, and the data and client dictionaries are updated.
- `tests/synthetic.py` follows the 0-120 visit window and reads the stage tomls'
  `sql/custom/` paths again (it had found no SQL to run).
  `tests/data/synthetic` has been regenerated.

## 2026-09-30 (merge of main)

- The two 50k NLP stages are replaced by Dylan's single `nlp_all_50k.workflow`
  (diagnosis, document_topic, surgery, no `select_by_table`), in
  `stage/manifest.py` and `manifest.toml`. Task versions follow this branch's
  schemas: diagnosis 3, document_topic 2, surgery 2.
- `nlp_document_tasks_50k.workflow` and `nlp_clinical_tasks_50k.workflow` are
  removed. The full `nlp_document_tasks.workflow` and
  `nlp_clinical_tasks.workflow` are unchanged.

## 2026-09-30

- Medication data now comes only from cumulus-library 6.3.4 core tables. No
  study SQL reads the study-built `pcx__medicationrequest` /
  `pcx__medicationdispense` tables, so those templates and the `fhir_resource`
  stage can be removed.
- `pcx__eligible_rx`: new structured source `rx_dispense` from
  `core__medicationdispense` (`whenhandedover_day`, matched to the rx valuesets,
  cancelled and declined dropped). New columns `methotrexate_dispense_first_day`
  and `chemo_dispense_first_day`. A dispense feeds `*_first_day` and `*_any_bool`
  but is not receipt, so `*_administered_*` stays LLM-only.
- `pcx__client_exposure`: new `dispense_first_day` column (NULL for RADIATION).
- Warn tables: `pcx__warn_outcome_exposure_order_only` shows the dispense day,
  `pcx__warn_eligible_therapy_precedes_t0` labels a dispense-sourced first day
  `rx_dispense`.
- Tests: `core__medicationdispense` and the seven `pcx__valueset_rx_*` tables in
  `tests/data/schema.sql`, seeded dispenses for p1, p2, p5, p6, and a new
  `test_dispense_is_structured_evidence_not_receipt`.
