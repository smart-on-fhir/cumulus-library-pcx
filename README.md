# PCX: medulloblastoma cohort and outcome study

Repository documentation checked 2026-09-10 against local configuration, valuesets, generated SQL and model sources. Database builds and clinical results were not rerun.

PCX is a Cumulus Library study under development for cross-network medulloblastoma analyses. The requirements below describe the intended scientific analysis; they are not a claim that survival estimation or treatment-effect analysis is implemented.

## Current repository state

The [main manifest](cumulus_library_pcx/manifest.toml) registers `study_population`, `study_variable`, `study_variable_wide`, `casedef`, `sample`, `nlp_clinical_tasks_wide`, `eligible`, and `outcome`. The NLP wide stage invokes eight Python builders with deployment discovery, nested-field validation, workflow-configured versions, and typed-empty fallback. Configure deployment suffixes in `tools/settings.py` or with `CUMULUS_PCX_NLP_DEPLOYMENTS`; see [builder contracts and SQL snapshots](chart_review.md). Clinical inference remains a separate, commented-out stage. `llm/athena/*.sql` are regression snapshots, not build inputs.

`elastic_output` is registered with `skip_by_default=true` on its parent submanifest and references an external, dated upload manifest. The installed Cumulus 6.3.1 loader does not propagate that parent setting to child actions; default-build portability remains an open issue. The builder integration does not establish a successful full Athena build or validated clinical results.

Current population settings differ from the all-age research goal:

- [Age-at-visit configuration](spreadsheet/include_age_at_visit.csv): 0–8 inclusive, applied to encounter age rather than diagnosis age.
- [Study period](spreadsheet/include_study_period.csv): starts 2008-01-01, blank end date, history enabled.
- [Utilization](spreadsheet/include_utilization.csv): 2–100000 distinct encounter-period ordinals and a 365–365000 day span from earliest retained encounter start to latest retained encounter end, using the encounter start when its end is missing. Encounters with missing end dates are retained, including pre-period history for patients with an in-window encounter; identical start/end pairs share one ordinal per patient. Raw missing end dates remain NULL in the output. The SQL applies these as patient-selection filters. This is not survival follow-up from diagnosis and can exclude patients with short observed histories, including early deaths.

These settings require reconciliation with the analysis population before comparing survival. See [limitations](limitations.md).

## Data definitions and documentation

There are 23 coded study variables: 4 diagnosis, 12 laboratory, and 7 medication CSVs. Codes match by `system` plus `code`; displays do not drive matching. Local codes and multi-site terminology coverage remain subject to validation. The fourth diagnosis variable, [methotrexate toxicity evidence](dx_methotrexate_toxic.md), has 30 rows across four review tiers; a match is not confirmed methotrexate toxicity.

See [chart-review outputs](chart_review.md), [deferred extraction work](deferred.md), and the [dated code review](reviews/code-review-2026-09-09/REVIEW.md) for integration details and open issues.

The seven medication valuesets contain 146 entries: six `rx_chemo_*` backbone sets (60 entries) and `rx_contrast_methotrexate` (86 entries: 76 RxNorm and 10 local/vendor codes). The `contrast` name identifies the study comparison variable; it does not establish route, dose, or indication. MedicationRequest evidence is not proof of administration. The [RX review](reviews/rxnorm-2026-09-08/REVIEW.md) distinguishes current membership from historical findings.

The shared [data dictionary](spreadsheet/data_dictionary.csv) is registered in the main manifest. It has 166 column definitions using Cumulus `name,display,description,details,type` fields. It is behind the current SQL: 35 medication columns still use the former `rx_agent_*` names, and the five `dx_methotrexate_toxic` columns are missing. Update the dictionary before relying on it for cross-network field assessment. It is not a complete dictionary of every SQL artifact or planned survival field. The earlier [valueset inventory](reviews/valueset_inventory.csv) is retained as a snapshot, not as the Cumulus dictionary.

`lab_folate_interpretation` currently names both a boolean evidence flag in `pcx__cohort_variable_wide` and a serum/plasma interpretation code in `pcx__cohort_variable_wide_lab`. The dictionary describes the collision using a string display fallback; that does not resolve the SQL naming conflict. Folate narrative and coded results remain in the raw lab fields and are not carried by the numeric wide projection. See [folate review](folate_review.md).

## Maintaining and building the study

Author valuesets in `spreadsheet/` and structural changes in study-owned templates or tools. Keep raw discovery results outside `spreadsheet/`: files such as `lab_*_candidates.csv` are otherwise discovered as study variables. Generated SQL and upload/submanifest files should be regenerated rather than edited individually.

From the repository root, with the project dependencies installed, regenerate the variable definitions and wide projections using the repository's module entry points:

```bash
python -m cumulus_library_pcx.stage.study_variable
python -m cumulus_library_pcx.stage.study_variable_wide
```

The stage generators now live under `cumulus_library_pcx.stage`; shared helpers remain under `tools`. The broader `python -m cumulus_library_pcx.tools.study_builder` also regenerates population, case-definition, sample, eligibility and outcome artifacts. Its eligibility/outcome generators still reference legacy or missing artifacts, so it is not a verified complete PCX build path. Generation does not activate commented manifest stages or execute Athena. Use the configured Cumulus Library environment for subsequent database materialization. This project does not declare its own `cumulus-study` console entry point in `pyproject.toml`.

Run `python -m pytest tests` for the model, strict-mode and synthetic DuckDB diagnosis-output regression suites with the project and test dependencies installed. Runtime mention validation warns by default; set `CUMULUS_PCX_STRICT_MENTIONS=1` before importing models to reject shared evidence/date inconsistencies. These tests do not validate clinical extraction accuracy or an Athena deployment. See [model documentation](llm.md) and [retrieval topics](query_topics.md).

Package metadata still contains PNOC030/ATRT wording, and older SQL artifacts remain. Active scope is determined by the manifest and current PCX definitions, not legacy filenames or package-description text. Deployment must preserve the manifest's relative access to the sibling `spreadsheet/` directory.

## Scientific requirements

**Goal:** Enable cube creation across the Cumulus and CBTN networks to compare overall survival by age at diagnosis, medulloblastoma subtype, methotrexate exposure, and radiation exposure.

### 1. Cohort definition — structured data

- **Diagnosis:** Medulloblastoma.
- **T₀:** First recorded medulloblastoma diagnosis. 
- **Age at diagnosis:** Include all ages, with a toggle for **<36 months** versus **≥36 months**.

### 2. Cohort characteristics — NLP plus structured data where available

| Characteristic          | Required distinction                       | Extraction requirement                                                                              |
|-------------------------|--------------------------------------------|-----------------------------------------------------------------------------------------------------|
| Medulloblastoma subtype | Group 3 and other subtypes, selectable     | Capture subtype, supporting evidence, and unknown or conflicting results.                           |
| Methotrexate treatment  | Received **prior to first event** versus not received, **any dose** | Identify actual administration and its date; distinguish planned treatment from treatment received. Count methotrexate as initial therapy only when the first administration precedes the first event. |
| Radiation treatment     | Received **prior to first event** versus not received, **any dose** | Identify delivered radiation and its date; distinguish planned treatment from treatment received. Count radiation as initial therapy only when the first delivery precedes the first event. |
| Initial-therapy sequence | Chemotherapy before radiation versus radiation before chemotherapy, within initial treatment | Compare the first delivered chemotherapy date with the first delivered radiation date, both prior to the first event. Patients with only one modality before the first event form their own strata. |
| Protocol name           | Named treatment protocol whenever documented | Capture the protocol name verbatim (for example ACNS0334) with its source and date. A protocol name does not establish enrollment, randomization, or treatment received. |

For both treatment variables, retain **unknown/not documented** separately from confirmed absence of treatment.

**First event.** The first event that would count in an EFS calculation: progression, recurrence/relapse, secondary malignancy, or death (see section 5). Treatment delivered after the first event, such as salvage radiation after recurrence, is not initial therapy and must not set the received-prior-to-first-event flags. Many patients receive radiation after progression or recurrence; counting that radiation would obscure the effect of radiation as initial therapy. For patients with no documented event, all delivered treatment counts as prior to first event, so these flags depend on event ascertainment and are not final until the EFS event list is agreed.

Chemotherapy in general (received versus not received) is not a required stratifier. Methotrexate receipt prior to first event is sufficient.

Clinical team guidance, 2026-09-10: the prior-to-first-event rule for both treatments, the initial-therapy sequence stratifier, and protocol-name capture.

Use `spreadsheet/rx_contrast_methotrexate.csv` as the single methotrexate valueset across
ingredients and formulations. It includes all codes formerly in the separate injectable
subset. Determine administration, route, dose, timing, and treatment phase from treatment
evidence. A valueset match alone does not establish receipt or high-dose intravenous therapy.

### 3. Primary summary measure — overall survival

- **Origin:** T₀.
- **Event:** Death, using `patient_deceased` or the corresponding vital-status field.
- **Event date:** Date of death.
- **Censoring date:** Last date documented alive for patients without a recorded death.
- **Required inputs:** Diagnosis date, vital status, death date when applicable, and last-known-alive date.

A deceased flag or last vital status alone is insufficient to calculate survival duration; associated dates are required.

### 4. Cross-network cube requirements

- Apply shared definitions and extraction rules across Cumulus and CBTN.
- Support filtering or stratification by network, age group, subtype, methotrexate exposure prior to first event, radiation exposure prior to first event, initial-therapy sequence (chemotherapy before radiation versus radiation before chemotherapy), and protocol name.
- Retain missingness and follow-up availability so Sarah can assess comparability.
- Resolve potential patient overlap before pooling network results.
- The treatment-exposure timing rule is receipt prior to first event (section 2). Grouping patients by treatment received at any later time would bias comparisons measured from diagnosis. The prior-to-first-event rule still classifies patients on information observed after T₀, so the analysis must address that (see [limitations](limitations.md)).

### 5. Reach goal — event-free survival (EFS)

Capture dated progression, relapse/recurrence, remission, and death records, with supporting evidence.

Before calculating EFS, agree on:

- Which events count as an EFS event.
- Whether the time origin is diagnosis or treatment initiation.
- How event-free follow-up and censoring are established.
- How conflicting or uncertain event dates are handled.

Remission should be captured as a disease-status transition; it should not automatically count as an adverse EFS event.

The EFS event list also defines the first event used by the treatment-exposure flags and the initial-therapy sequence in section 2, so it must be agreed before those flags are computed, even if EFS itself is not calculated.

### Immediate next step

Refresh the registered column-level data dictionary for renamed medication and new toxicity fields, then use it to assess field availability in both networks. Resolve the folate column-name collision and the age/utilization selection mismatch, then validate subtype, actual treatment receipt and dated outcomes on reviewed patient samples before enabling comparative survival outputs.
