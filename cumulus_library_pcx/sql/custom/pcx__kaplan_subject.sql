-- Kaplan-Meier count source: one row per outcome subject.
-- Diagnosis uses the latest documented disease subtype from client_diagnosis.
-- No diagnosis, age, or prior-treatment exclusions are applied here.
-- NULL dimensions are avoided so cube NULLs represent subtotals.
-- A documented EFS event without a usable date is efs_status event with
-- event_free_survival_years and event_free_survival_months Not Reported:
-- curves count the event but use no duration for it.
-- Survival is labeled in whole years (FLOOR(days / 365.25), capped at >=10,
-- the PCX-30 label) and in whole months (FLOOR(days / 30.4375), the year
-- divided by 12, no cap). The exported cubes use months.
-- Exposure strata are INITIAL therapy, from time zero to the first event
-- (pcx__outcome_exposure), never ever-exposure, so salvage therapy after
-- relapse is not counted. had_initial_methotrexate and had_initial_radiation
-- are Yes, No (initial therapy documented without it, or explicitly not
-- received), Not Reported (unknown, including an undated event that may
-- precede every exposure) or Not Applicable (no t0). Missing documentation is
-- Not Reported, never No.
-- protocol_name is the coded protocol of any systemic therapy regimen ever
-- documented (pcx__llm_systemic_therapy_regimen, dated or not, not only initial
-- therapy): every distinct protocol named, sorted and comma-joined (such as
-- ACNS0334,HEAD_START), Not Reported when none is (NONE_OF_THE_ABOVE is not a
-- protocol). Naming a protocol does not establish enrollment.
-- protocol_name_by_date lists the same protocols in the order they are first
-- documented: the earliest regimen_start_day, else the date of the note that
-- names the protocol (pcx__llm_note_date, an upper bound on when it started).
-- Undated protocols go last, ties are alphabetical. Not in the cubes, which
-- keep the alphabetical label so a set of protocols is always one stratum.
-- documented_trial_arm is the explicitly documented arm of an ACNS0334
-- regimen only, so REGIMEN_B is always the high-dose methotrexate arm:
-- REGIMEN_A, REGIMEN_B, Conflicting when notes document both (a patient is
-- randomized once, so this needs chart review), Not Reported when an ACNS0334
-- regimen documents no arm, Not Applicable when no ACNS0334 regimen is
-- documented. Arms of other protocols are ignored.

CREATE TABLE pcx__kaplan_subject AS
WITH
protocol_named AS (
    SELECT  regimen.subject_ref,
            regimen.protocol_name,
            MIN(COALESCE(regimen.regimen_start_day, note_day.note_date)) AS first_day
    FROM    pcx__llm_systemic_therapy_regimen AS regimen
    LEFT JOIN pcx__llm_note_date AS note_day
      ON    note_day.subject_ref = regimen.subject_ref
     AND    note_day.note_ref    = regimen.note_ref
    WHERE   regimen.protocol_name <> 'NONE_OF_THE_ABOVE'
    GROUP BY regimen.subject_ref, regimen.protocol_name
),
protocol AS (
    SELECT  subject_ref,
            ARRAY_JOIN(ARRAY_AGG(protocol_name ORDER BY protocol_name), ',') AS protocol_name,
            ARRAY_JOIN(ARRAY_AGG(protocol_name ORDER BY first_day NULLS LAST, protocol_name), ',')
                                                                    AS protocol_name_by_date
    FROM    protocol_named
    GROUP BY subject_ref
),
acns0334_arm AS (
    SELECT  subject_ref,
            NULLIF(documented_trial_arm, 'NONE_OF_THE_ABOVE') AS arm
    FROM    pcx__llm_systemic_therapy_regimen
    WHERE   protocol_name = 'ACNS0334'
),
trial_arm AS (
    SELECT  subject_ref,
            CASE
                WHEN COUNT(DISTINCT arm) > 1 THEN 'Conflicting'
                WHEN COUNT(DISTINCT arm) = 1 THEN MIN(arm)
                ELSE 'Not Reported'
            END AS documented_trial_arm
    FROM    acns0334_arm
    GROUP BY subject_ref
)
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
            WHEN outcome.t0_day IS NULL
            THEN 'Not Applicable'
            WHEN outcome.os_days IS NULL OR outcome.os_days < 0
            THEN 'Not Reported'
            ELSE CAST(
                CAST(FLOOR(outcome.os_days / 30.4375E0) AS INTEGER)
                AS VARCHAR
            )
        END AS overall_survival_months,

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
            WHEN outcome.t0_day IS NULL
            THEN 'Not Applicable'
            WHEN outcome.efs_days IS NULL OR outcome.efs_days < 0
            THEN 'Not Reported'
            ELSE CAST(
                CAST(FLOOR(outcome.efs_days / 30.4375E0) AS INTEGER)
                AS VARCHAR
            )
        END AS event_free_survival_months,

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
            WHEN outcome.t0_day IS NULL
            THEN 'Not Applicable'
            WHEN outcome.had_initial_methotrexate_bool
            THEN 'Yes'
            WHEN NOT outcome.had_initial_methotrexate_bool
            THEN 'No'
            ELSE 'Not Reported'
        END AS had_initial_methotrexate,

        CASE
            WHEN outcome.t0_day IS NULL
            THEN 'Not Applicable'
            WHEN outcome.had_initial_radiation_bool
            THEN 'Yes'
            WHEN NOT outcome.had_initial_radiation_bool
            THEN 'No'
            ELSE 'Not Reported'
        END AS had_initial_radiation,

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
            WHEN outcome.initial_therapy_sequence = 'NO_INITIAL_THERAPY'
            THEN 'no_initial_radiation_or_chemo'
            ELSE 'Not Reported'
        END AS initial_treatment_order,

        COALESCE(protocol.protocol_name, 'Not Reported') AS protocol_name,
        COALESCE(protocol.protocol_name_by_date, 'Not Reported') AS protocol_name_by_date,
        COALESCE(trial_arm.documented_trial_arm, 'Not Applicable') AS documented_trial_arm

FROM pcx__outcome AS outcome
LEFT JOIN pcx__client_diagnosis AS dx
    ON dx.subject_ref = outcome.subject_ref
LEFT JOIN protocol
    ON protocol.subject_ref = outcome.subject_ref
LEFT JOIN trial_arm
    ON trial_arm.subject_ref = outcome.subject_ref;
