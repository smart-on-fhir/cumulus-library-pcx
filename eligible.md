# Which patients are eligible?

The [eligible.toml](cumulus_library_pcx/eligible.toml) stage distills the clinical trial criteria
retrospectively from EHR data. As of Sept 2026 there are differences from the trial, noted here.

We attempt to implement the criteria defined in [PMC12833527](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/),
while understanding we may not have all the criteria available in the first pass of this PCX study.

The stage produces two subject-level tables. Every criterion is a boolean column: TRUE = yes, FALSE = no,
NULL = not evaluable from the evidence on hand (no t0, no birthdate, no definitive surgery date).

| table                  | grain                                   | purpose                                                                                                                                              |
|------------------------|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `pcx__eligible`        | one row per case-definition subject     | **discovery cohort**, all ages: every ACNS0334 criterion as its own column. Age, prior methotrexate, prior chemotherapy and prior radiation are **flags, never exclusions** |
| `pcx__eligible_trial`  | subset of `pcx__eligible`               | **trial-like cohort**: MB evidence AND under 36 months at definitive surgery AND NOT ATRT AND no chemotherapy, methotrexate or radiation before t0. A NULL criterion excludes, so no t0 means not eligible |

⚠️ One defect still changes who lands in `pcx__eligible_trial` ([workplan.md](workplan.md) 2.3): SNOMED 428061005 is tier-1 ATRT in `casedef.csv` but "Malignant tumor of brain" in `dx_brain_cancer.csv`. The NULL time zero and the "requires treatment evidence" defects (workplan 2.1, 2.2) were fixed on 2026-09-30.

## Relaxed criteria: flags, not exclusions

The PCX study (PNOC030 comparator) is broader than the ACNS0334 trial. Three trial criteria are relaxed:
they no longer remove anyone from `pcx__eligible`, they are yes/no flags on it instead.

| trial criterion                     | flag in `pcx__eligible`                                                   | TRUE means                                  | NULL when                          |
|-------------------------------------|---------------------------------------------------------------------------|---------------------------------------------|------------------------------------|
| age under 36 months                 | `age_under_36_months_at_t0` (diagnosis) and `age_under_36_months_at_definitive_surgery` (ACNS0334) | under 36 months at that day | no day or no birthdate             |
| no prior methotrexate               | `methotrexate_prior_to_t0_bool`                                           | methotrexate dated before t0                | no t0                              |
| no prior chemotherapy               | `chemo_prior_to_t0_bool`                                                  | backbone chemotherapy dated before t0       | no t0                              |
| no prior radiation                  | `radiation_prior_to_t0_bool`                                              | radiation dated before t0                   | no t0                              |

A `*_prior_to_t0_bool` flag is FALSE when t0 is known and nothing is dated before it, which includes no evidence
at all and undated evidence. The "ever" flags `methotrexate_any_bool`, `chemo_any_bool` and `radiation_any_bool`
(any source, any time) are FALSE when there is no evidence, never NULL.

`pcx__eligible_trial` still applies all of them, strictly: ACNS0334 excludes any prior chemotherapy, so prior
methotrexate excludes there the same way the backbone agents do.

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
| [include_age_at_visit.csv](spreadsheet/include_age_at_visit.csv) | study_population keeps encounters at ages 0–120 (integer years at the visit), every age banded in [age_group.csv](spreadsheet/age_group.csv) |
| `pcx__eligible_surgery.sql`                                      | trial criterion: `age_months_at_definitive_surgery < 36`. In `pcx__eligible` it is a flag, beside `age_under_36_months_at_t0`, `age_band_at_t0` and `age_under_8_months_at_t0` |

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
| [surgery.py](cumulus_library_pcx/llm/models/surgery.py) | preferred: the earliest LLM operation whose `extent_of_resection` is a resection (gross total, near total, partial) |
| [proc_craniotomy.csv](spreadsheet/proc_craniotomy.csv)  | fallback: first tier 1 craniotomy `proc_performed_day` (candidate codes, verify)                                  |

`definitive_surgery_source` records which one was used. Residual disease inputs (`llm_residual_disease_bool`,
`llm_residual_tumor_area_cm2_max`) are reported for the high-risk stratum but not applied as criteria.

### Medication

Methotrexate is the "causal contrast"; the six backbone agents are chemotherapy. `pcx__eligible_rx.sql` unions every
dated candidate with its source and takes the earliest day per exposure:

| file                                                                       | criteria                                                                                              |
|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| [rx_contrast_methotrexate.csv](spreadsheet/rx_contrast_methotrexate.csv)   | methotrexate **orders** (MedicationRequest `authoredOn`) and **dispenses** (MedicationDispense `whenHandedOver`); not counted as chemotherapy |
| [rx_chemo_carboplatin.csv](spreadsheet/rx_chemo_carboplatin.csv), [cisplatin](spreadsheet/rx_chemo_cisplatin.csv), [cyclophosphamide](spreadsheet/rx_chemo_cyclophosphamide.csv), [etoposide](spreadsheet/rx_chemo_etoposide.csv), [thiotepa](spreadsheet/rx_chemo_thiotepa.csv), [vincristine](spreadsheet/rx_chemo_vincristine.csv) | chemotherapy **orders** and **dispenses** |
| [systemic_therapy.py](cumulus_library_pcx/llm/models/systemic_therapy.py)  | LLM agents with `delivery_status = ADMINISTERED` (receipt): methotrexate by agent name; **every** administered agent counts as chemotherapy, methotrexate included (asymmetry, workplan 3.4) |

Orders and dispenses both come from cumulus-library core (`core__medicationrequest`, `core__medicationdispense`) and
match the same valueset codes. Orders are linked to study_population encounters, dispenses are matched for every case
subject, and cancelled or declined dispenses are dropped. A dispense is the pharmacy handing the drug over, not
administration, so the `*_administered_*` columns stay LLM-only and a dispensed-only exposure still shows in
`pcx__warn_outcome_exposure_order_only`.

Views by strictness, as implemented:

* `pcx__eligible`: all case-definition subjects, every criterion evaluated, no filter;
* `pcx__eligible_trial`: the intersection above. A subject with t0 and no treatment evidence at all has every prior flag FALSE, so it is in the trial view (received-or-not is the separate `*_any_bool` flags);
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

### Prior chemotherapy and methotrexate

`chemo_prior_to_t0_bool` (backbone agents) and `methotrexate_prior_to_t0_bool` are TRUE when the first dated day,
from any source, is before `t0_day`. Both are flags in `pcx__eligible`. The trial view excludes TRUE and NULL (no t0).

### Prior radiation therapy

`radiation_prior_to_t0_bool` is TRUE when `radiation_first_day` is before `t0_day`. A flag in `pcx__eligible`, the
trial view excludes TRUE and NULL (no t0). `radiation_first_day` is the earliest of:

| file                                                        | criteria                                                                                         |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| [proc_radiation.csv](spreadsheet/proc_radiation.csv)        | tier 1 procedure `proc_performed_day` (candidate codes, verify)                                  |
| [dx_radiation.csv](spreadsheet/dx_radiation.csv)            | tier 1 encounter code `dx_recorded_date` (candidate codes; the tier 2 "history of irradiation" codes are ignored, workplan 3.5) |
| [radiation.py](cumulus_library_pcx/llm/models/radiation.py) | LLM rounds with `delivery_status = ADMINISTERED`. `EXPLICITLY_NOT_RECEIVED` is kept as `llm_explicitly_not_received_bool` for `pcx__warn_eligible_radiation_evidence_conflict`, it is not a criterion |

---
## pcx__eligible ❓

| table                                                                                 | purpose                                                                                                   |
|---------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| [pcx__eligible_dx.sql](cumulus_library_pcx/sql/custom/pcx__eligible_dx.sql)               | case-definition subjects, t0, age at t0, MB and ATRT evidence, LLM diagnosis summary (M-stage, anaplastic) |
| [pcx__eligible_surgery.sql](cumulus_library_pcx/sql/custom/pcx__eligible_surgery.sql)     | definitive surgery day and source, age at definitive surgery, under 36 months, residual disease inputs     |
| [pcx__eligible_rx.sql](cumulus_library_pcx/sql/custom/pcx__eligible_rx.sql)               | first methotrexate and chemotherapy days by source, `methotrexate_prior_to_t0_bool`, `chemo_prior_to_t0_bool` |
| [pcx__eligible_radiation.sql](cumulus_library_pcx/sql/custom/pcx__eligible_radiation.sql) | first radiation day by source, `radiation_prior_to_t0_bool`, craniospinal and proton flags                 |
| [pcx__eligible.sql](cumulus_library_pcx/sql/custom/pcx__eligible.sql)                     | every criterion as a flag column, nobody excluded (discovery cohort)                                       |
| [pcx__eligible_trial.sql](cumulus_library_pcx/sql/custom/pcx__eligible_trial.sql)         | strict intersection (trial-like cohort)                                                                    |

The eligible SQL reads four LLM wide tables built by the `llm_clinical_wide` stage: `pcx__llm_diagnosis_wide`,
`pcx__llm_surgery_wide`, `pcx__llm_systemic_therapy_agent`, `pcx__llm_radiation_wide` (empty when no NLP output exists,
so every `llm_*` column is then NULL). Every column is declared in [data_dictionary.csv](spreadsheet/data_dictionary.csv).
The QA stage's `pcx__warn_eligible_*` tables measure each known weakness before the SQL is changed
(see [reviews/qa-warn-2026-09-11/REVIEW.md](reviews/qa-warn-2026-09-11/REVIEW.md)).
