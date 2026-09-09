# PCX: medulloblastoma cohort and outcome study

PCX is a Cumulus Library study under development for cross-network medulloblastoma analyses. The requirements below describe the intended scientific analysis; they are not a claim that survival estimation or treatment-effect analysis is implemented.

## Current repository state

The [main manifest](cumulus_library_pcx/manifest.toml) enables `study_population`, `study_variable`, `study_variable_wide`, `casedef`, and `sample`. Elastic query/output, eligibility, outcome, client-view, QA, and cube stages are commented out. Existing SQL or model files for an inactive stage do not establish a working analysis or a completed database build.

Current population settings differ from the all-age research goal:

- [Age-at-visit configuration](spreadsheet/include_age_at_visit.csv): 0–8 inclusive, applied to encounter age rather than diagnosis age.
- [Study period](spreadsheet/include_study_period.csv): starts 2008-01-01, blank end date, history enabled.
- [Utilization](spreadsheet/include_utilization.csv): 2–100000 distinct encounter-period ordinals and a 365–365000 day span from earliest retained encounter start to latest non-null encounter end. The SQL applies these as patient-selection filters. This is not survival follow-up from diagnosis and can exclude patients with short observed histories, including early deaths.

These settings require reconciliation with the analysis population before comparing survival. See [limitations](limitations.md).

## Data definitions and documentation

There are 22 coded study variables: 3 diagnosis, 12 laboratory, and 7 medication CSVs. Codes match by `system` plus `code`; displays do not drive matching. Local codes and multi-site terminology coverage remain subject to validation.

| Laboratory valueset | Entries | Current scope or open issue |
| --- | ---: | --- |
| Absolute neutrophil count | 2 | Blood count; coverage not comprehensively audited |
| ALT | 9 | Five LOINCs and four local codes |
| AST | 6 | Three LOINCs and three local codes |
| Creatinine | 8 | One LOINC and seven local candidates; proposed additional LOINCs not yet added |
| Serum/plasma folate | 3 | Concentrations only |
| RBC folate | 3 | Separate from serum/plasma |
| Whole-blood folate | 2 | Separate specimen variable |
| Folate interpretation | 3 | Qualitative/interpretive evidence, not numeric concentrations |
| Unspecified folate | 3 | Local specimen and result type unresolved |
| Hemoglobin | 33 | Includes reticulocyte hemoglobin code 923, which remains a scope concern |
| Platelets | 9 | Includes manual, optical, estimated and EDTA-context counts |
| Total bilirubin | 1 | Serum/plasma mass concentration; coverage not comprehensively audited |

The seven medication valuesets contain 131 entries, including a single 71-code methotrexate set. MedicationRequest evidence is not proof of administration. The [RX review](reviews/rxnorm-2026-09-08/REVIEW.md) distinguishes current membership from historical findings.

The shared [data dictionary](spreadsheet/data_dictionary.csv) is registered in the main manifest. It has 166 actual column definitions using Cumulus `name,display,description,details,type` fields, including all current variable-wide projections and selected shared fields. It is not a complete dictionary of every SQL artifact or planned survival field. The earlier [valueset inventory](reviews/valueset_inventory.csv) is retained as a snapshot, not as the Cumulus dictionary.

`lab_folate_interpretation` currently names both a boolean evidence flag in `pcx__cohort_variable_wide` and a serum/plasma interpretation code in `pcx__cohort_variable_wide_lab`. The dictionary describes the collision using a string display fallback; that does not resolve the SQL naming conflict. Folate narrative and coded results remain in the raw lab fields and are not carried by the numeric wide projection. See [folate review](folate_review.md).

## Maintaining and building the study

Author valuesets in `spreadsheet/` and structural changes in study-owned templates or tools. Keep raw discovery results outside `spreadsheet/`: files such as `lab_*_candidates.csv` are otherwise discovered as study variables. Generated SQL and upload/submanifest files should be regenerated rather than edited individually.

From the repository root, with the project dependencies installed, regenerate the variable definitions and wide projections using the repository's module entry points:

```bash
python -m cumulus_library_pcx.tools.study_variable
python -m cumulus_library_pcx.tools.study_variable_wide
```

The broader `python -m cumulus_library_pcx.tools.study_builder` also regenerates population, case-definition, sample, eligibility and outcome artifacts. Generation does not activate commented manifest stages or execute Athena. Use the configured Cumulus Library environment for subsequent database materialization. This project does not declare its own `cumulus-study` console entry point in `pyproject.toml`.

The LLM schema regression suite is in `tests/test_llm_models.py` and can be run with `python -m pytest tests/test_llm_models.py`. These tests do not validate clinical extraction accuracy. See [model documentation](llm.md) and [retrieval topics](query_topics.md).

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
| Methotrexate treatment  | Received versus not received, **any dose** | Identify actual administration and its date; distinguish planned treatment from treatment received. |
| Radiation treatment     | Received versus not received, **any dose** | Identify delivered radiation and its date; distinguish planned treatment from treatment received.   |

For both treatment variables, retain **unknown/not documented** separately from confirmed absence of treatment.

Use `spreadsheet/rx_agent_methotrexate.csv` as the single methotrexate valueset across
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
- Support filtering or stratification by network, age group, subtype, methotrexate exposure, and radiation exposure.
- Retain missingness and follow-up availability so Sarah can assess comparability.
- Resolve potential patient overlap before pooling network results.
- Define the treatment-exposure timing rule before comparing survival: grouping patients by treatment received at any later time can bias comparisons measured from diagnosis.

### 5. Reach goal — event-free survival (EFS)

Capture dated progression, relapse/recurrence, remission, and death records, with supporting evidence.

Before calculating EFS, agree on:

- Which events count as an EFS event.
- Whether the time origin is diagnosis or treatment initiation.
- How event-free follow-up and censoring are established.
- How conflicting or uncertain event dates are handled.

Remission should be captured as a disease-status transition; it should not automatically count as an adverse EFS event.

### Immediate next step

Use the registered column-level data dictionary to assess field availability in both networks. Resolve the folate column-name collision and the age/utilization selection mismatch, then validate subtype, actual treatment receipt and dated outcomes on reviewed patient samples before enabling comparative survival outputs.
