# pcx Kaplan-Meier count cubes, shared and exported (stage/counts_kaplan.py).
# Based on the PCX-30 OS and EFS _cube.csv files, with these differences:
#   no site column (each site's export reaches the aggregator under that site, which adds it
#   when cubes are combined)
#   survival in whole months (overall_survival_months, event_free_survival_months, no cap)
#   instead of PCX-30's whole years
#   the two exposure strata are initial therapy (had_initial_methotrexate, had_initial_radiation:
#   Yes, No, Not Reported, Not Applicable) instead of PCX-30's ever columns
#   two added strata, protocol_name and documented_trial_arm (ACNS0334 arm only)
# A Kaplan-Meier curve can be read from survival months x status at any stratum. The source,
# pcx__kaplan_subject, is one row per eligible subject with every label built
# upstream (sql/custom/pcx__kaplan_subject.sql). Counts are distinct patients with a
# floor of 1, approved for PCX (PROTOCOL.md 8.1), like the unsuppressed PCX-30 files.
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
