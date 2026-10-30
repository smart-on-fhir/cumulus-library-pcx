# Kaplan-Meier survival counts

The opt-in `counts_kaplan` stage ([cumulus-study.md](cumulus-study.md#stages)) turns the
eligibility and outcome tables into count cubes. They are exported to the Cumulus aggregator,
where overall survival (OS) and event-free survival (EFS) curves can be drawn without any
patient-level data leaving the site.

The cubes are defined in [counts_kaplan.workflow](cumulus_library_pcx/counts_kaplan.workflow).
Column definitions are in [data_dictionary.csv](spreadsheet/data_dictionary.csv). The decisions
behind them are in [PROTOCOL.md](PROTOCOL.md) section 8.1.

## Where the counts come from

```
pcx__eligible               one row per case-definition subject (eligible.md)
  └─ pcx__outcome           vital status, first event, OS and provisional EFS
       └─ pcx__kaplan_subject          one labeled row per subject, all subjects
            └─ pcx__kaplan_subject_strict   the strict cohort, plottable on both curves
```

- `pcx__eligible` holds time zero (t0), age and every ACNS0334 criterion as a flag. See
  [eligible.md](eligible.md), especially [Time zero](eligible.md#time-zero-t0).
- `pcx__outcome` adds OS and the provisional EFS. EFS is provisional because response
  assessment is missing ([limitations.md](limitations.md), section 4).
- `pcx__kaplan_subject` gives each subject plain labels (Yes, No, Not Reported, and so on) so
  they can be counted. It applies no diagnosis, age or treatment exclusions.
- `pcx__kaplan_subject_strict` keeps only the strict cohort (below).

## Reading a cube

- Each row is one combination of the columns, and `cnt` is the number of **distinct patients**
  in it.
- A blank (NULL) column means "all values": that row is a subtotal.
- `cumulus__none` means the value is missing or not evaluable, which is different from `false`.
- Every cell is exported, down to 1 patient (the floor of 1 approved for PCX).

## The cubes

| Cube | Counts patients in | Broken down by |
|---|---|---|
| `pcx__cube_kaplan_os` | `pcx__kaplan_subject` (all subjects) | diagnosis, OS months, vital status, under 36 months, initial methotrexate, initial radiation, molecular subtype, protocol, ACNS0334 arm |
| `pcx__cube_kaplan_efs` | `pcx__kaplan_subject` (all subjects) | diagnosis, EFS months, EFS status, under 36 months, initial methotrexate, initial radiation, molecular subtype, initial treatment order, protocol, ACNS0334 arm |
| `pcx__cube_kaplan_strict_os` | `pcx__kaplan_subject_strict` | same columns as `pcx__cube_kaplan_os` |
| `pcx__cube_kaplan_strict_efs` | `pcx__kaplan_subject_strict` | same columns as `pcx__cube_kaplan_efs` |
| `pcx__cube_eligible_casedef` | `pcx__eligible` | gender, age band at t0, t0 source, tier 1 medulloblastoma code, LLM medulloblastoma diagnosis, confirmed ATRT |
| `pcx__cube_eligible_prior_therapy` | `pcx__eligible` | age band at t0, under 36 months at definitive surgery, methotrexate before t0, chemotherapy before t0, radiation before t0 |
| `pcx__cube_eligible_risk` | `pcx__eligible` | age band at t0, definitive surgery source, under 8 months at t0, metastatic, anaplastic, residual disease |
| `pcx__cube_eligible_exposure` | `pcx__eligible` | age band at t0, methotrexate ever, chemotherapy ever, radiation ever, craniospinal radiation, proton radiation |
| `pcx__cube_outcome_os` | `pcx__outcome` | gender, age band at t0, death, OS end day imputed |
| `pcx__cube_outcome_efs` | `pcx__outcome` | age band at t0, EFS event, first event type, how the EFS row ends, EFS end day imputed |
| `pcx__cube_outcome_initial_therapy` | `pcx__outcome` | age band at t0, initial methotrexate, initial chemotherapy, initial radiation, initial therapy sequence |

"Initial" means from t0 up to the first event, so salvage therapy after a relapse is not
counted. "Ever" means at any time.

## Kaplan cube labels

| Column | Values |
|---|---|
| `overall_survival_months`, `event_free_survival_months` | whole months from t0 (days ÷ 30.4375, no cap). Not Applicable when there is no t0. Not Reported when there is no usable duration |
| `vital_status` | alive, deceased |
| `efs_status` | event, event-free |
| `age_at_diagnosis_under_36mo` | Yes, No, Not Reported |
| `had_initial_methotrexate`, `had_initial_radiation` | Yes, No, Not Reported (unknown), Not Applicable (no t0) |
| `subtype` | WNT, SHH, Group 3, Group 4, non-WNT/non-SHH, or NOS/NEC when no medulloblastoma molecular group is documented. NOS/NEC is also used for patients who are not medulloblastoma, so filter on `diagnosis` |
| `diagnosis` | the latest documented embryonal subtype (MEDULLOBLASTOMA, ATRT, ...), or Not Reported |
| `initial_treatment_order` | `chemo_before_radiation`, `radiation_before_chemotherapy`, `radiation_and_chemo_same_day`, `chemo_only_no_initial_radiation`, `radiation_only_no_initial_chemo`, `no_initial_radiation_or_chemo`, Not Reported, Not Applicable |
| `protocol_name` | every protocol named in the notes, comma-joined and sorted (such as `ACNS0334,HEAD_START`), or Not Reported |
| `documented_trial_arm` | the ACNS0334 arm only: REGIMEN_A, REGIMEN_B, Conflicting (notes disagree, needs chart review), Not Reported (no arm documented), Not Applicable (no ACNS0334 regimen) |

An EFS event with no usable date is counted as `event` with Not Reported months. A curve can
count the event but cannot place it in time, so curves drawn from the all-subject cubes look
somewhat better than reality.

## The strict cohort

`pcx__kaplan_subject_strict` keeps subjects who meet all three conditions:

1. **Diagnosis:** medulloblastoma, molecular subtype Group 3, Group 4 or non-WNT/non-SHH.
2. **Treatment:** an ACNS0334, PBTC_026 or CCG99703 regimen in the notes (with or without a
   documented arm), or high-dose methotrexate in initial therapy.
3. **Plottable:** a t0 and whole-month durations for both OS and EFS.

Because of condition 3, the strict cubes have no Not Applicable or Not Reported months. Undated
EFS events are left out entirely, so the strict EFS counts undercount events.

## Exporting and uploading

```
cumulus-library export -s ./cumulus_library_pcx -t pcx --stage counts_kaplan
cumulus-library upload -t pcx
```

The zip holds these eleven cubes plus the study metadata tables. The general study cubes in
[counts.workflow](cumulus_library_pcx/counts.workflow) are not included: uploading them is a
separate, deliberate step.
