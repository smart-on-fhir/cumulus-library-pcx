# Which patients are eligible?

The [eligible.toml](cumulus_library_pcx/eligible.toml) stage distills the clinical trial criteria
retrospectively from EHR data. As of Sept 2026 there are differences from the trial, noted here.

We attempt to implement the criteria defined in [PMC12833527](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/),
while understanding we may not have all the criteria available in the first pass of this PCX study.

The stage produces two subject-level tables. Every criterion is a nullable boolean: TRUE = met, FALSE = not met,
NULL = not evaluable from the evidence on hand (never "met", never "not met").

| table                  | grain                                   | purpose                                                                                                                                              |
|------------------------|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `pcx__eligible`        | one row per case-definition subject     | **discovery cohort**, all ages: every ACNS0334 criterion as its own column, plus any-time exposure flags                                              |
| `pcx__eligible_trial`  | subset of `pcx__eligible`               | **trial-like cohort**: MB evidence AND under 36 months at definitive surgery AND NOT ATRT AND no prior chemotherapy AND no prior radiation. A NULL criterion excludes |

⚠️ Three defects in the current SQL change who lands in `pcx__eligible_trial`; they are the first cohort items in [workplan.md](workplan.md) (2.1–2.3): a NULL time zero makes the two `no_prior_*` criteria read TRUE, the trial view requires positive radiation and chemotherapy evidence rather than absence of prior evidence, and SNOMED 428061005 is tier-1 ATRT in `casedef.csv` but "Malignant tumor of brain" in `dx_brain_cancer.csv`.

## Time zero (t=0)

`t0_day` is the start day of the first study-population encounter that carries a **tier 1 medulloblastoma** code from
[casedef.csv](spreadsheet/casedef.csv) (`pcx__eligible_dx.sql`). Tier 2 codes (history of brain neoplasm, unspecified brain neoplasm)
are evidence only: a subject with no tier 1 medulloblastoma code has a NULL `t0_day` and stays a candidate. The `etmr`,
`pineoblastoma` and `cns_embryonal` subtypes in casedef.csv currently do **not** produce a t0 (workplan 2.5).

Age is `DATE_DIFF('month', birthdate, day)` from `core__patient.birthdate`; on Athena this is completed months
(workplan 1.8 makes it engine-independent). `pcx__cohort_casedef` keeps its own anchor (first casedef encounter of any
subtype and tier) for note sampling, so a subject can have two different time zeros (workplan 2.6, warn table
`pcx__warn_eligible_t0_anchor_disagree`).

## Inclusion criteria ☑️

### Encounter

Applied upstream by the study_population stage, not by eligible.

| file                                                           | criteria                                                        |
|----------------------------------------------------------------|-----------------------------------------------------------------|
| [include_utilization.csv](spreadsheet/include_utilization.csv) | ≥ 2 distinct encounter periods spanning ≥ 365 days              |
| [include_study_period.csv](spreadsheet/include_study_period.csv) | encounters from 2008-01-01, with prior history                |

This is a follow-up filter, not censoring: it removes early deaths (see [limitations.md](limitations.md)).

### Patient age

| file                                                             | criteria                                                                                                        |
|------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| [include_age_at_visit.csv](spreadsheet/include_age_at_visit.csv) | study_population keeps encounters at ages 0–8 (integer years at the visit)                                      |
| `pcx__eligible_surgery.sql`                                      | trial criterion: `age_months_at_definitive_surgery < 36`; `pcx__eligible` also reports `age_band_at_t0` and `age_under_8_months_at_t0` |

### Diagnosis

Required. The structured and LLM evidence are reported side by side and OR-ed in the trial view.

| file                                                         | criteria                                                                                                    |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| [casedef.csv](spreadsheet/casedef.csv)                       | `medulloblastoma_tier1_bool`: any tier 1 medulloblastoma code (this also sets t0)                          |
| [diagnosis.py](cumulus_library_pcx/llm/models/diagnosis.py)  | `llm_medulloblastoma_bool`: any note in `pcx__llm_diagnosis_wide` with `disease_subtype = MEDULLOBLASTOMA` |
| [dx_medulloblastoma.csv](spreadsheet/dx_medulloblastoma.csv) | builds `pcx__cohort_dx_medulloblastoma` for discovery; **not read by the eligible SQL**, and its ICD-O-3 codes are absent from casedef.csv (workplan 2.4) |

### Surgery

Optional in `pcx__eligible`, **required** in `pcx__eligible_trial` (a NULL age at definitive surgery excludes).

| file                                                    | criteria                                                                                                        |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| [surgery.py](cumulus_library_pcx/llm/models/surgery.py) | preferred: the LLM operation whose free-text `surgery_role` contains "definitive" (an enum is planned, 3.6)       |
| [proc_craniotomy.csv](spreadsheet/proc_craniotomy.csv)  | fallback: first tier 1 craniotomy `proc_performed_day` (candidate codes, verify)                                  |

`definitive_surgery_source` records which one was used. Residual disease inputs (`llm_residual_disease_bool`,
`llm_residual_tumor_area_cm2_max`) are reported for the high-risk stratum but not applied as criteria.

### Medication

Methotrexate is the "causal contrast"; the six backbone agents are chemotherapy. `pcx__eligible_rx.sql` unions every
dated candidate with its source and takes the earliest day per exposure:

| file                                                                       | criteria                                                                                              |
|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| [rx_contrast_methotrexate.csv](spreadsheet/rx_contrast_methotrexate.csv)   | methotrexate **orders** (MedicationRequest `authoredOn`); not counted as chemotherapy                  |
| [rx_chemo_carboplatin.csv](spreadsheet/rx_chemo_carboplatin.csv), [cisplatin](spreadsheet/rx_chemo_cisplatin.csv), [cyclophosphamide](spreadsheet/rx_chemo_cyclophosphamide.csv), [etoposide](spreadsheet/rx_chemo_etoposide.csv), [thiotepa](spreadsheet/rx_chemo_thiotepa.csv), [vincristine](spreadsheet/rx_chemo_vincristine.csv) | chemotherapy **orders** |
| [systemic_therapy.py](cumulus_library_pcx/llm/models/systemic_therapy.py)  | LLM agents with `delivery_status = ADMINISTERED` (receipt): methotrexate by agent name; **every** administered agent counts as chemotherapy, methotrexate included (asymmetry, workplan 3.4) |

Views by strictness, as implemented:

* `pcx__eligible`: all case-definition subjects, every criterion evaluated, no filter;
* `pcx__eligible_trial`: the intersection above. Because `no_prior_chemotherapy_bool` is NULL when no chemotherapy is recorded at all, the trial view today also requires 1+ chemotherapy (workplan 2.2 separates "received chemotherapy" from "no prior chemotherapy");
* clinical trial view with organ-function labs and staging: out of scope for the current implementation (see [registry_eligibility.py](cumulus_library_pcx/llm/models/registry_eligibility.py) and [laboratory.md](laboratory.md)).

----

## Exclusion criteria 🚫

### ATRT diagnosis

`atrt_confirmed_bool` is TRUE when either source says ATRT; the trial view requires NOT ATRT.

| file                                                        | criteria                                                                                                      |
|-------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| [casedef.csv](spreadsheet/casedef.csv)                      | `atrt_tier1_bool`: any tier 1 `atrt` row. A subject whose **only** casedef evidence is ATRT is not a case-definition subject at all |
| [diagnosis.py](cumulus_library_pcx/llm/models/diagnosis.py) | `llm_atrt_bool`: any single note with `disease_subtype = ATRT` (one note is enough, warn table `pcx__warn_eligible_dx_subtype_conflict`) |
| [dx_atrt.csv](spreadsheet/dx_atrt.csv)                      | builds `pcx__cohort_dx_atrt` for discovery; **not read by the eligible SQL**; still carries C71.9 / 191.9 at tier 3 |

### Prior chemotherapy

`chemo_prior_to_t0_bool = chemo_first_day < t0_day` (either source). The trial view excludes TRUE. NULL when there is
no dated chemotherapy or no t0.

### Prior radiation therapy

`radiation_prior_to_t0_bool = radiation_first_day < t0_day`, where `radiation_first_day` is the earliest of:

| file                                                        | criteria                                                                                         |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| [proc_radiation.csv](spreadsheet/proc_radiation.csv)        | tier 1 procedure `proc_performed_day` (candidate codes, verify)                                  |
| [dx_radiation.csv](spreadsheet/dx_radiation.csv)            | tier 1 encounter code `dx_recorded_date` (candidate codes; the tier 2 "history of irradiation" codes are ignored, workplan 3.5) |
| [radiation.py](cumulus_library_pcx/llm/models/radiation.py) | LLM rounds with `delivery_status = ADMINISTERED`; `EXPLICITLY_NOT_RECEIVED` in any note sets `no_prior_radiation_bool` TRUE |

---
## pcx__eligible ❓

| table                                                                                 | purpose                                                                                                   |
|---------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| [pcx__eligible_dx.sql](cumulus_library_pcx/custom/pcx__eligible_dx.sql)               | case-definition subjects, t0, age at t0, MB and ATRT evidence, LLM diagnosis summary (M-stage, anaplastic) |
| [pcx__eligible_surgery.sql](cumulus_library_pcx/custom/pcx__eligible_surgery.sql)     | definitive surgery day and source, age at definitive surgery, under 36 months, residual disease inputs     |
| [pcx__eligible_rx.sql](cumulus_library_pcx/custom/pcx__eligible_rx.sql)               | first methotrexate and chemotherapy days by source, `chemo_prior_to_t0_bool`                               |
| [pcx__eligible_radiation.sql](cumulus_library_pcx/custom/pcx__eligible_radiation.sql) | first radiation day by source, `radiation_prior_to_t0_bool`, craniospinal and proton flags                 |
| [pcx__eligible.sql](cumulus_library_pcx/custom/pcx__eligible.sql)                     | every criterion as a nullable column (discovery cohort)                                                    |
| [pcx__eligible_trial.sql](cumulus_library_pcx/custom/pcx__eligible_trial.sql)         | strict intersection (trial-like cohort)                                                                    |

The eligible SQL reads four LLM wide tables built by the `nlp_clinical_tasks_wide` stage: `pcx__llm_diagnosis_wide`,
`pcx__llm_surgery_wide`, `pcx__llm_systemic_therapy_agent`, `pcx__llm_radiation_wide` (empty when no NLP output exists,
so every `llm_*` column is then NULL). Every column is declared in [data_dictionary.csv](spreadsheet/data_dictionary.csv).
The QA stage's `pcx__warn_eligible_*` tables measure each known weakness before the SQL is changed
(see [reviews/qa-warn-2026-09-11/REVIEW.md](reviews/qa-warn-2026-09-11/REVIEW.md)).
