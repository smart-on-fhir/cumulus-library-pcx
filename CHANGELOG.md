# Changelog

Short, human-readable notes on what changed and why. Newest first.

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
