--  =====================================================================
--  Kaplan-Meier count source: one row per eligible subject, PCX-30 labels
--
--  Source for counts_kaplan.workflow, whose OS and EFS cubes have the same columns and labels as the PCX-30
--  _cube.csv files, except site, which the aggregator adds per site.
--  No dimension is ever NULL, so a NULL in a cube is always a subtotal.
--    overall_survival_years, event_free_survival_years
--        whole years from t0_day, FLOOR(days / 365.25), 10 and over is >=10.
--        365.25E0 is a DOUBLE, while a plain 365.25 is a DECIMAL, which Trino rounds
--        to 2 places, so day 3652 (9.9986 years) would become 10.
--        Not Applicable   no t0_day, so no origin
--        Not Reported     no end day, or the end day is before t0_day
--    diagnosis           Medulloblastoma, because pcx__eligible excludes ATRT
--    subtype             latest documented molecular group from
--                        pcx__client_diagnosis, NOS/NEC when none is documented
--    age_at_diagnosis_under_36mo   from age at definitive surgery
--    ever_methotrexate, radiation  Yes when a dated exposure exists,
--                        otherwise Not Reported (no evidence is unknown, never No)
--    initial_treatment_order       initial_therapy_sequence in PCX-30 words.
--                        Not Reported when there is no chemo or radiation evidence,
--                        no_initial_radiation_or_chemo when all of it follows the first event
--  EFS keeps the provisional censoring of pcx__outcome (efs_censor_source).
--  =====================================================================
CREATE  TABLE   pcx__kaplan_subject AS
SELECT  outcome.subject_ref,
        'Medulloblastoma'                                                   AS diagnosis,
        CASE
            WHEN outcome.t0_day IS NULL                                     THEN 'Not Applicable'
            WHEN outcome.os_days IS NULL                                    THEN 'Not Reported'
            WHEN outcome.os_days < 0                                        THEN 'Not Reported'
            WHEN outcome.os_days / 365.25E0 >= 10                             THEN '>=10'
            ELSE CAST(CAST(FLOOR(outcome.os_days / 365.25E0) AS INTEGER) AS VARCHAR)
        END                                                                 AS overall_survival_years,
        CASE
            WHEN outcome.os_event_bool                                      THEN 'deceased'
            ELSE                                                                 'alive'
        END                                                                 AS vital_status,
        CASE
            WHEN outcome.t0_day IS NULL                                     THEN 'Not Applicable'
            WHEN outcome.efs_days IS NULL                                   THEN 'Not Reported'
            WHEN outcome.efs_days < 0                                       THEN 'Not Reported'
            WHEN outcome.efs_days / 365.25E0 >= 10                            THEN '>=10'
            ELSE CAST(CAST(FLOOR(outcome.efs_days / 365.25E0) AS INTEGER) AS VARCHAR)
        END                                                                 AS event_free_survival_years,
        CASE
            WHEN outcome.efs_event_bool                                     THEN 'event'
            ELSE                                                                 'event-free'
        END                                                                 AS efs_status,
        CASE
            WHEN outcome.age_under_36_months_at_definitive_surgery IS NULL  THEN 'Not Reported'
            WHEN outcome.age_under_36_months_at_definitive_surgery          THEN 'Yes'
            ELSE                                                                 'No'
        END                                                                 AS age_at_diagnosis_under_36mo,
        CASE
            WHEN outcome.methotrexate_first_day IS NOT NULL                 THEN 'Yes'
            ELSE                                                                 'Not Reported'
        END                                                                 AS ever_methotrexate,
        CASE
            WHEN outcome.radiation_first_day IS NOT NULL                    THEN 'Yes'
            ELSE                                                                 'Not Reported'
        END                                                                 AS radiation,
        CASE dx.molecular_group_ever
            WHEN 'WNT'                                                      THEN 'WNT'
            WHEN 'SHH'                                                      THEN 'SHH'
            WHEN 'GROUP_3'                                                  THEN 'Group 3'
            WHEN 'GROUP_4'                                                  THEN 'Group 4'
            WHEN 'NON_WNT_NON_SHH'                                          THEN 'non-WNT/non-SHH'
            ELSE                                                                 'NOS/NEC'
        END                                                                 AS subtype,
        CASE
            WHEN outcome.t0_day IS NULL                                     THEN 'Not Applicable'
            WHEN outcome.initial_therapy_sequence = 'CHEMOTHERAPY_BEFORE_RADIATION' THEN 'chemo_before_radiation'
            WHEN outcome.initial_therapy_sequence = 'RADIATION_BEFORE_CHEMOTHERAPY' THEN 'radiation_before_chemotherapy'
            WHEN outcome.initial_therapy_sequence = 'SAME_DAY'              THEN 'radiation_and_chemo_same_day'
            WHEN outcome.initial_therapy_sequence = 'CHEMOTHERAPY_ONLY'     THEN 'chemo_only_no_initial_radiation'
            WHEN outcome.initial_therapy_sequence = 'RADIATION_ONLY'        THEN 'radiation_only_no_initial_chemo'
            WHEN outcome.chemo_first_day IS NULL
             AND outcome.radiation_first_day IS NULL                        THEN 'Not Reported'
            ELSE                                                                 'no_initial_radiation_or_chemo'
        END                                                                 AS initial_treatment_order
FROM    pcx__outcome                AS outcome
LEFT JOIN pcx__client_diagnosis     AS dx ON dx.subject_ref = outcome.subject_ref
