-- Kaplan-Meier count source: one row per outcome subject.
-- Diagnosis uses the latest documented disease subtype from client_diagnosis.
-- No diagnosis, age, or prior-treatment exclusions are applied here.
-- NULL dimensions are avoided so cube NULLs represent subtotals.
-- A documented EFS event without a usable date is efs_status event with
-- event_free_survival_years Not Reported: curves count the event but use no
-- duration for it. Its initial_treatment_order is Not Reported when
-- efs_censor_source is event_timing_uncertain, since an undated event may
-- precede every exposure.

CREATE TABLE pcx__kaplan_subject AS
SELECT  outcome.subject_ref,
        COALESCE(dx.disease_subtype_ever, 'Not Reported') AS diagnosis,

        CASE
            WHEN outcome.t0_day IS NULL
            THEN 'Not Applicable'
            WHEN outcome.os_days IS NULL OR outcome.os_days < 0
            THEN 'Not Reported'
            WHEN outcome.os_days / 365.25E0 >= 10
            THEN '>=10'
            ELSE CAST(
                CAST(FLOOR(outcome.os_days / 365.25E0) AS INTEGER)
                AS VARCHAR
            )
        END AS overall_survival_years,

        CASE
            WHEN outcome.os_event_bool
            THEN 'deceased'
            ELSE 'alive'
        END AS vital_status,

        CASE
            WHEN outcome.t0_day IS NULL
            THEN 'Not Applicable'
            WHEN outcome.efs_days IS NULL OR outcome.efs_days < 0
            THEN 'Not Reported'
            WHEN outcome.efs_days / 365.25E0 >= 10
            THEN '>=10'
            ELSE CAST(
                CAST(FLOOR(outcome.efs_days / 365.25E0) AS INTEGER)
                AS VARCHAR
            )
        END AS event_free_survival_years,

        CASE
            WHEN outcome.efs_event_bool
            THEN 'event'
            ELSE 'event-free'
        END AS efs_status,

        CASE
            WHEN outcome.age_under_36_months_at_definitive_surgery IS NULL
            THEN 'Not Reported'
            WHEN outcome.age_under_36_months_at_definitive_surgery
            THEN 'Yes'
            ELSE 'No'
        END AS age_at_diagnosis_under_36mo,

        CASE
            WHEN outcome.methotrexate_first_day IS NOT NULL
            THEN 'Yes'
            ELSE 'Not Reported'
        END AS ever_methotrexate,

        CASE
            WHEN outcome.radiation_first_day IS NOT NULL
            THEN 'Yes'
            ELSE 'Not Reported'
        END AS radiation,

        CASE dx.molecular_group_ever
            WHEN 'WNT'             THEN 'WNT'
            WHEN 'SHH'             THEN 'SHH'
            WHEN 'GROUP_3'         THEN 'Group 3'
            WHEN 'GROUP_4'         THEN 'Group 4'
            WHEN 'NON_WNT_NON_SHH' THEN 'non-WNT/non-SHH'
            ELSE 'NOS/NEC'
        END AS subtype,

        CASE
            WHEN outcome.t0_day IS NULL
            THEN 'Not Applicable'
            WHEN outcome.initial_therapy_sequence = 'CHEMOTHERAPY_BEFORE_RADIATION'
            THEN 'chemo_before_radiation'
            WHEN outcome.initial_therapy_sequence = 'RADIATION_BEFORE_CHEMOTHERAPY'
            THEN 'radiation_before_chemotherapy'
            WHEN outcome.initial_therapy_sequence = 'SAME_DAY'
            THEN 'radiation_and_chemo_same_day'
            WHEN outcome.initial_therapy_sequence = 'CHEMOTHERAPY_ONLY'
            THEN 'chemo_only_no_initial_radiation'
            WHEN outcome.initial_therapy_sequence = 'RADIATION_ONLY'
            THEN 'radiation_only_no_initial_chemo'
            WHEN outcome.chemo_first_day IS NULL AND outcome.radiation_first_day IS NULL
            THEN 'Not Reported'
            WHEN outcome.efs_censor_source = 'event_timing_uncertain'
            THEN 'Not Reported'
            ELSE 'no_initial_radiation_or_chemo'
        END AS initial_treatment_order

FROM pcx__outcome AS outcome
LEFT JOIN pcx__client_diagnosis AS dx
    ON dx.subject_ref = outcome.subject_ref;
