# Which patients are eligible?

The [eligible.toml](cumulus_library_pcx/eligible.toml) stage distills the clinical trial criteria
retrospectively from EHR data. There are differences from the trial, noted here.

We attempt to implement the criteria defined in [PMC12833527](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/),
while understanding we may not have all the criteria available in the first pass of this PCX study.

The stage produces two subject-level tables. Every criterion is a nullable boolean: TRUE = met, FALSE = not met,
NULL = not evaluable from the evidence on hand (never "met", never "not met").

| table                  | grain                                   | purpose                                                                                                                                              |
|------------------------|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `pcx__eligible`        | one row per case-definition subject     | **discovery cohort**, all ages: every ACNS0334 criterion as its own column, plus any-time exposure flags                                              |
| `pcx__eligible_trial`  | subset of `pcx__eligible`               | **trial-like cohort**: MB evidence AND under 36 months at definitive surgery AND NOT ATRT AND no prior chemotherapy (methotrexate included) AND no prior radiation. A NULL criterion excludes |

A subject with a time zero and no therapy records counts as "no prior therapy" and can enter
the trial-like cohort. That is an absence of records, not a documented absence, so it depends
on how complete the site's medication and procedure data are. Open defects are in
[WORKPLAN.md](WORKPLAN.md) (Case definition, Eligibility).

## Time zero (t=0)

`t0_day` is the start day of the first study-population encounter that carries a **tier 1 medulloblastoma** code from
[casedef.csv](spreadsheet/casedef.csv) (`eligible_dx.sql`). Tier 2 codes (history of brain neoplasm, unspecified brain neoplasm)
are evidence only: a subject with no tier 1 medulloblastoma code has a NULL `t0_day` and stays a candidate. The `etmr`,
`pineoblastoma` and `cns_embryonal` subtypes in casedef.csv currently do **not** produce a t0 (see WORKPLAN.md).

Age is `DATE_DIFF('month', birthdate, day)` from `core__patient.birthdate`; on Athena this is completed months
(WORKPLAN.md makes it engine-independent). `pcx__cohort_casedef` keeps its own anchor (first casedef encounter of any
subtype and tier) for note sampling, so a subject can have two different time zeros (WORKPLAN.md, warn table
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
| [include_age_at_visit.csv](spreadsheet/include_age_at_visit.csv) | no age restriction: study_population keeps encounters at ages 0–120. The trial enrolled young children; here age is a flag, not a population filter |
| `eligible_surgery.sql`                                           | trial criterion: `age_under_36_months_at_definitive_surgery`                                                    |
| `eligible.sql`                                                   | reported only: `age_under_36_months_at_t0`, `age_band_at_t0`, `age_under_8_months_at_t0`                        |

### Diagnosis

Required. The structured and LLM evidence are reported side by side and OR-ed in the trial view.

| file                                                         | criteria                                                                                                    |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| [casedef.csv](spreadsheet/casedef.csv)                       | `medulloblastoma_tier1_bool`: any tier 1 medulloblastoma code (this also sets t0)                          |
| [diagnosis.py](cumulus_library_pcx/llm/models/diagnosis.py)  | `llm_medulloblastoma_bool`: any note in `pcx__llm_diagnosis_wide` with `disease_subtype = MEDULLOBLASTOMA` |
| [dx_medulloblastoma.csv](spreadsheet/dx_medulloblastoma.csv) | builds `pcx__cohort_dx_medulloblastoma` for discovery; **not read by the eligible SQL**, and its ICD-O-3 codes are absent from casedef.csv (see WORKPLAN.md) |

### Surgery

Optional in `pcx__eligible`, **required** in `pcx__eligible_trial` (a NULL age at definitive surgery excludes).

| file                                                    | criteria                                                                                                        |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| [surgery.py](cumulus_library_pcx/llm/models/surgery.py) | preferred: the earliest LLM operation whose `extent_of_resection` is a resection (gross total, near total, partial) |
| [proc_craniotomy.csv](spreadsheet/proc_craniotomy.csv)  | fallback: first tier 1 craniotomy `proc_performed_day` (candidate codes, verify)                                  |

`definitive_surgery_source` records which one was used. Residual disease inputs (`llm_residual_disease_bool`,
`llm_residual_tumor_area_cm2_max`) are reported for the high-risk stratum but not applied as criteria.

### Medication

Methotrexate is the "causal contrast"; the six backbone agents are chemotherapy. `eligible_rx.sql` unions every
dated candidate with its source and takes the earliest day per exposure:

| file                                                                       | criteria                                                                                              |
|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| [rx_contrast_methotrexate.csv](spreadsheet/rx_contrast_methotrexate.csv)   | methotrexate **orders** (MedicationRequest `authoredOn`); prior methotrexate excludes from the trial-like cohort like the backbone agents |
| [rx_chemo_carboplatin.csv](spreadsheet/rx_chemo_carboplatin.csv), [cisplatin](spreadsheet/rx_chemo_cisplatin.csv), [cyclophosphamide](spreadsheet/rx_chemo_cyclophosphamide.csv), [etoposide](spreadsheet/rx_chemo_etoposide.csv), [thiotepa](spreadsheet/rx_chemo_thiotepa.csv), [vincristine](spreadsheet/rx_chemo_vincristine.csv) | chemotherapy **orders** |
| `core__medicationdispense`                                                 | pharmacy **dispenses** (`whenHandedOver`, cancelled and declined dropped) for the same valuesets: closer to receipt than an order, not proof of administration |
| [systemic_therapy.py](cumulus_library_pcx/llm/models/systemic_therapy.py)  | LLM agents with `delivery_status = ADMINISTERED` (receipt): methotrexate by agent name; **every** administered agent counts as chemotherapy, whatever the agent (WORKPLAN.md) |

Views by strictness, as implemented:

* `pcx__eligible`: all case-definition subjects, every criterion evaluated, no filter;
* `pcx__eligible_trial`: the intersection above. It does not require any treatment evidence: a subject with a time zero and nothing dated before it has the prior-therapy flags FALSE;
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

`chemo_prior_to_t0_bool` and `methotrexate_prior_to_t0_bool` are TRUE when the first dated
exposure (order, dispense or LLM-administered agent) is before `t0_day`. They are FALSE when
`t0_day` is known and nothing is dated before it, including no evidence or only undated
evidence, and NULL only when `t0_day` is NULL. The trial-like cohort excludes TRUE and NULL.
`chemo_any_bool` and `methotrexate_any_bool` report exposure at any time.

### Prior radiation therapy

`radiation_prior_to_t0_bool` follows the same TRUE / FALSE / NULL rule, where the first radiation day is the earliest of:

| file                                                        | criteria                                                                                         |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| [proc_radiation.csv](spreadsheet/proc_radiation.csv)        | tier 1 procedure `proc_performed_day` (candidate codes, verify)                                  |
| [dx_radiation.csv](spreadsheet/dx_radiation.csv)            | tier 1 encounter code `dx_recorded_date` (candidate codes; the tier 2 "history of irradiation" codes are ignored, WORKPLAN.md) |
| [radiation.py](cumulus_library_pcx/llm/models/radiation.py) | LLM rounds with `delivery_status = ADMINISTERED`; `EXPLICITLY_NOT_RECEIVED` in any note is reported as `llm_explicitly_not_received_bool` |

---
## pcx__eligible ❓

| table                                                                                 | purpose                                                                                                   |
|---------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| [eligible_dx.sql](cumulus_library_pcx/sql/custom/eligible_dx.sql)               | case-definition subjects, t0, age at t0, MB and ATRT evidence, LLM diagnosis summary (M-stage, anaplastic) |
| [eligible_surgery.sql](cumulus_library_pcx/sql/custom/eligible_surgery.sql)     | definitive surgery day and source, age at definitive surgery, under 36 months, residual disease inputs     |
| [eligible_rx.sql](cumulus_library_pcx/sql/custom/eligible_rx.sql)               | first methotrexate and chemotherapy days by source, the `*_prior_to_t0_bool` and `*_any_bool` flags                               |
| [eligible_radiation.sql](cumulus_library_pcx/sql/custom/eligible_radiation.sql) | first radiation day by source, `radiation_prior_to_t0_bool`, craniospinal and proton flags                 |
| [eligible.sql](cumulus_library_pcx/sql/custom/eligible.sql)                     | every criterion as a nullable column (discovery cohort)                                                    |
| [eligible_trial.sql](cumulus_library_pcx/sql/custom/eligible_trial.sql)         | strict intersection (trial-like cohort)                                                                    |

The eligible SQL reads four LLM wide tables built by the `llm_clinical_wide` stage: `pcx__llm_diagnosis_wide`,
`pcx__llm_surgery_wide`, `pcx__llm_systemic_therapy_agent`, `pcx__llm_radiation_wide` (empty when no NLP output exists,
so every `llm_*` column is then NULL). Every column is declared in [data_dictionary.csv](spreadsheet/data_dictionary.csv).
The QA stage's `pcx__warn_eligible_*` tables (`tests/sql/custom/`) measure each known weakness.
