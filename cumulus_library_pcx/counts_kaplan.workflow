# pcx Kaplan-Meier count cubes, shared and exported (stage/counts_kaplan.py).
# Based on the PCX-30 OS and EFS _cube.csv files, with these differences:
#   no site column (each site's export reaches the aggregator under that site, which adds it
#   when cubes are combined)
#   survival in whole months (overall_survival_months, event_free_survival_months, no cap)
#   instead of PCX-30's whole years
#   the two exposure strata are initial therapy (had_initial_methotrexate, had_initial_radiation:
#   Yes, No, Not Reported, Not Applicable) instead of PCX-30's ever columns
#   two added strata, protocol_name and documented_trial_arm (ACNS0334 arm only)
# A Kaplan-Meier curve can be read from survival months x status at any stratum. The source of
# cube_kaplan_os and cube_kaplan_efs, pcx__kaplan_subject, is one row per eligible subject with
# every label built upstream (sql/custom/pcx__kaplan_subject.sql). cube_kaplan_strict_os and
# cube_kaplan_strict_efs have the same columns over pcx__kaplan_subject_strict, the strict
# cohort (sql/custom/pcx__kaplan_subject_strict.sql): medulloblastoma Group 3, Group 4 or
# non-WNT/non-SHH, on ACNS0334, PBTC_026 or CCG99703 or initial high-dose methotrexate, with a
# t0 and whole-month OS and EFS durations, so it has no Not Applicable or Not Reported months.
# Counts are distinct patients with a floor of 1, approved for PCX (PROTOCOL.md 8.1), like the
# unsuppressed PCX-30 files.
# The cube_eligible_* and cube_outcome_* tables count the tables that feed the Kaplan source,
# pcx__eligible and pcx__outcome, one row per subject, in themed cubes of a few columns each.
# Dates, day counts, continuous ages and the free-text protocol_names are left out. A NULL
# flag is counted as cumulus__none (not evaluable), separate from false.
# Workflow format: https://docs.smarthealthit.org/cumulus/library/workflows/counts.html

config_type = "counts"

[tables.cube_kaplan_os]
min_subject = 1
description = "Eligible medulloblastoma patients by whole months of overall survival from t0, vital status, age under 36 months, methotrexate in initial therapy, radiation in initial therapy, molecular subtype, documented protocol and documented ACNS0334 arm. Based on the PCX-30 OS cube, without its site column. cnt is patients."
source_table = "pcx__kaplan_subject"
table_cols =["diagnosis",
            "overall_survival_months",
            "vital_status",
            "age_at_diagnosis_under_36mo",
            "had_initial_methotrexate",
            "had_initial_radiation",
            "subtype",
            "protocol_name",
            "documented_trial_arm"]


[tables.cube_kaplan_efs]
min_subject = 1
description = "Eligible medulloblastoma patients by whole months of provisional event-free survival from t0, event status, age under 36 months, methotrexate in initial therapy, radiation in initial therapy, molecular subtype, initial treatment order, documented protocol and documented ACNS0334 arm. Based on the PCX-30 EFS cube, without its site column. A documented event without a usable date is event with Not Reported months: count the event, but use no duration for it. cnt is patients."
source_table = "pcx__kaplan_subject"
table_cols =["diagnosis",
            "event_free_survival_months",
            "efs_status",
            "age_at_diagnosis_under_36mo",
            "had_initial_methotrexate",
            "had_initial_radiation",
            "subtype",
            "initial_treatment_order",
            "protocol_name",
            "documented_trial_arm"]


[tables.cube_kaplan_strict_os]
min_subject = 1
description = "Strict cohort (pcx__kaplan_subject_strict: medulloblastoma Group 3, Group 4 or non-WNT/non-SHH, on ACNS0334, PBTC_026 or CCG99703 or initial high-dose methotrexate, plottable on both curves) by whole months of overall survival from t0, vital status, age under 36 months, methotrexate in initial therapy, radiation in initial therapy, molecular subtype, documented protocol and documented ACNS0334 arm. Same columns as cube_kaplan_os. cnt is patients."
source_table = "pcx__kaplan_subject_strict"
table_cols =["diagnosis",
            "overall_survival_months",
            "vital_status",
            "age_at_diagnosis_under_36mo",
            "had_initial_methotrexate",
            "had_initial_radiation",
            "subtype",
            "protocol_name",
            "documented_trial_arm"]


[tables.cube_kaplan_strict_efs]
min_subject = 1
description = "Strict cohort (pcx__kaplan_subject_strict: medulloblastoma Group 3, Group 4 or non-WNT/non-SHH, on ACNS0334, PBTC_026 or CCG99703 or initial high-dose methotrexate, plottable on both curves) by whole months of provisional event-free survival from t0, event status, age under 36 months, methotrexate in initial therapy, radiation in initial therapy, molecular subtype, initial treatment order, documented protocol and documented ACNS0334 arm. Same columns as cube_kaplan_efs. Documented events without a usable date are not in this cohort, so EFS events are undercounted. cnt is patients."
source_table = "pcx__kaplan_subject_strict"
table_cols =["diagnosis",
            "event_free_survival_months",
            "efs_status",
            "age_at_diagnosis_under_36mo",
            "had_initial_methotrexate",
            "had_initial_radiation",
            "subtype",
            "initial_treatment_order",
            "protocol_name",
            "documented_trial_arm"]

[tables.cube_eligible_casedef]
min_subject = 1
description = "Case-definition subjects in pcx__eligible by gender, age band at t0, t0 source, tier 1 medulloblastoma code, LLM medulloblastoma diagnosis and confirmed ATRT. cnt is patients."
source_table = "pcx__eligible"
table_cols = ["gender",
              "age_band_at_t0",
              "t0_source",
              "medulloblastoma_tier1_bool",
              "llm_medulloblastoma_bool",
              "atrt_confirmed_bool"]

[tables.cube_eligible_prior_therapy]
min_subject = 1
description = "Case-definition subjects in pcx__eligible by age band at t0, age under 36 months at definitive surgery, and methotrexate, chemotherapy and radiation before t0. cnt is patients."
source_table = "pcx__eligible"
table_cols = ["age_band_at_t0",
              "age_under_36_months_at_definitive_surgery",
              "methotrexate_prior_to_t0_bool",
              "chemo_prior_to_t0_bool",
              "radiation_prior_to_t0_bool"]

[tables.cube_eligible_risk]
min_subject = 1
description = "Case-definition subjects in pcx__eligible by age band at t0, definitive surgery source, and the ACNS0334 high-risk inputs (age under 8 months, LLM metastatic, LLM anaplastic, LLM residual disease). cnt is patients."
source_table = "pcx__eligible"
table_cols = ["age_band_at_t0",
              "definitive_surgery_source",
              "age_under_8_months_at_t0",
              "llm_metastatic_bool",
              "llm_anaplastic_bool",
              "llm_residual_disease_bool"]

[tables.cube_eligible_exposure]
min_subject = 1
description = "Case-definition subjects in pcx__eligible by age band at t0 and exposure at any time: methotrexate, chemotherapy, radiation, LLM craniospinal and LLM proton radiation. cnt is patients."
source_table = "pcx__eligible"
table_cols = ["age_band_at_t0",
              "methotrexate_any_bool",
              "chemo_any_bool",
              "radiation_any_bool",
              "llm_craniospinal_bool",
              "llm_proton_bool"]

[tables.cube_outcome_os]
min_subject = 1
description = "Subjects in pcx__outcome by gender, age band at t0, overall survival event (death) and whether the OS end day is imputed from a month or year date. cnt is patients."
source_table = "pcx__outcome"
table_cols = ["gender",
              "age_band_at_t0",
              "os_event_bool",
              "os_end_day_imputed_bool"]

[tables.cube_outcome_efs]
min_subject = 1
description = "Subjects in pcx__outcome by age band at t0, provisional EFS event, first event type, how the EFS row ends (efs_censor_source) and whether the EFS end day is imputed. cnt is patients."
source_table = "pcx__outcome"
table_cols = ["age_band_at_t0",
              "efs_event_bool",
              "first_event_type",
              "efs_censor_source",
              "efs_end_day_imputed_bool"]

[tables.cube_outcome_initial_therapy]
min_subject = 1
description = "Subjects in pcx__outcome by age band at t0, methotrexate, chemotherapy and radiation in initial therapy (t0 to first event), and initial therapy sequence. cnt is patients."
source_table = "pcx__outcome"
table_cols = ["age_band_at_t0",
              "had_initial_methotrexate_bool",
              "had_initial_chemo_bool",
              "had_initial_radiation_bool",
              "initial_therapy_sequence"]
