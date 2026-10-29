-- Kaplan-Meier demo cohort: the pcx__kaplan_subject rows that meet the demo
-- criteria and can be plotted on both the OS and the EFS curve.
-- Diagnosis   medulloblastoma, molecular subtype Group 3, Group 4 or
--             non-WNT/non-SHH.
-- Treatment   any ACNS0334, PBTC_026 or CCG99703 regimen in
--             pcx__llm_systemic_therapy_regimen, with or without a documented
--             arm and whatever other protocols the patient has, or high-dose
--             methotrexate in initial therapy
--             (had_initial_methotrexate, t0 to first event only).
-- Plottable   a valid t0 and a whole-month duration for both OS and EFS.
--             Not Applicable (no t0) and Not Reported (no usable duration,
--             including an undated event) rows are left out, so this table
--             undercounts EFS events whose timing is unknown.
-- os_months and efs_months are the month labels as integers for plotting. The
-- hard cast fails the build if a new non-numeric label ever appears.

CREATE TABLE pcx__kaplan_subject_demo AS
SELECT  ks.*,
        CAST(ks.overall_survival_months AS INTEGER)    AS os_months,
        CAST(ks.event_free_survival_months AS INTEGER) AS efs_months
FROM    pcx__kaplan_subject AS ks
WHERE   ks.diagnosis = 'MEDULLOBLASTOMA'
AND     ks.subtype IN ('Group 3', 'Group 4', 'non-WNT/non-SHH')
AND     (ks.subject_ref IN (
            SELECT  subject_ref
            FROM    pcx__llm_systemic_therapy_regimen
            WHERE   protocol_name IN ('ACNS0334', 'PBTC_026', 'CCG99703'))
         OR ks.had_initial_methotrexate = 'Yes')
AND     ks.overall_survival_months NOT IN ('Not Applicable', 'Not Reported')
AND     ks.event_free_survival_months NOT IN ('Not Applicable', 'Not Reported');
