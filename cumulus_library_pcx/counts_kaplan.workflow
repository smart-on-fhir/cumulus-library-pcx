# pcx Kaplan-Meier count cubes, shared and exported (stage/counts_kaplan.py).
# Same columns, column order and labels as the PCX-30 OS and EFS _cube.csv files, except
# site: each site's export reaches the aggregator under that site, which adds it when cubes
# are combined. A Kaplan-Meier curve can be read from survival years x status at any stratum. The source,
# pcx__kaplan_subject, is one row per eligible subject with every label built
# upstream (sql/custom/pcx__kaplan_subject.sql). Counts are distinct patients with a
# floor of 1, approved for PCX (PROTOCOL.md 8.1), like the unsuppressed PCX-30 files.
# Workflow format: https://docs.smarthealthit.org/cumulus/library/workflows/counts.html

config_type = "counts"

[tables.cube_kaplan_os]
min_subject = 1
description = "Eligible medulloblastoma patients by whole years of overall survival from t0, vital status, age under 36 months, methotrexate ever, radiation ever, and molecular subtype, in the PCX-30 OS cube layout without its site column. cnt is patients."
source_table = "pcx__kaplan_subject"
table_cols =["diagnosis",
            "overall_survival_years",
            "vital_status",
            "age_at_diagnosis_under_36mo",
            "ever_methotrexate",
            "radiation",
            "subtype"]


[tables.cube_kaplan_efs]
min_subject = 1
description = "Eligible medulloblastoma patients by whole years of provisional event-free survival from t0, event status, age under 36 months, methotrexate ever, radiation ever, molecular subtype and initial treatment order, in the PCX-30 EFS cube layout without its site column. A documented event without a usable date is event with Not Reported years: count the event, but use no duration for it. cnt is patients."
source_table = "pcx__kaplan_subject"
table_cols =["diagnosis",
            "event_free_survival_years",
            "efs_status",
            "age_at_diagnosis_under_36mo",
            "ever_methotrexate",
            "radiation",
            "subtype",
            "initial_treatment_order"]
