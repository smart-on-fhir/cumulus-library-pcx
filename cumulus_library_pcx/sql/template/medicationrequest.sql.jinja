-- ============================================================================
-- Grain: one row per core__medicationrequest row (id x category coding x
--        medication coding), enriched one-to-one from the raw MedicationRequest.
--
-- Purpose: MedicationRequest metadata that core__medicationrequest does not
--        surface - course of therapy, status reason, prior prescription, the
--        first dosage instruction, order-level dosage bounds across every
--        dosage step (a steroid taper is several steps), and the dispense
--        request (days supply, refills, quantity, validity period).
--
-- Sources: core__medicationrequest, medicationrequest (raw Cumulus ETL)
-- Docs:    schema.md, "Table layers"
--
-- Coverage interval (the one derived block, parsed once here per the source
-- layer rule):
--   expected_supply_days   - expectedSupplyDuration normalised to days
--                            (d, wk, mo, a - any other unit yields NULL) with
--                            the sentinel values in params turned to NULL
--   supply_days_total      - expected_supply_days x (1 + refills allowed),
--                            capped at params.coverage_max_days
--   coverage_start_date    - dosage bounds start, else the authoredOn day
--   supply_end_date        - coverage_start_date + supply_days_total
--   coverage_end_date      - the EARLIER of dosage_end_date and supply_end_date,
--                            so a discontinued order ends at its discontinue
--                            date and an open order ends when the supply does
--   coverage_end_date_type - which of the two supplied coverage_end_date
--
-- Notes:
--   * MedicationRequest.statusChanged is FHIR R5 and later. The R4 export has
--     no such element - dosage_end_date and dispense_validity_end_date are the
--     stop-date proxies.
--   * Epic writes expectedSupplyDuration only on intent = order,
--     category = community e-prescriptions (86 percent of those). Inpatient
--     and clinic-administered (outpatient category) orders never carry one,
--     so infused biologics get no coverage interval here.
--   * Refills are a permission, not an observation. Uncapped, an order with a
--     90-day supply and 11 refills claims three years of exposure from the day
--     it was written (the export's p99 was 4,370 days, max 36,500), and Epic
--     writes 0 / 999 / 9999 as "as directed" sentinels on 361K rows. The cap
--     is one prescription cycle - a renewal, a later order, or a fill extends
--     coverage, an unused refill does not.
--   * Raw struct fields deeper than two levels exist only when the export
--     carried them (Cumulus ETL builds the schema from the data there).
--     Everything referenced below was seen in the Epic export - confirm with
--     information_schema.columns on dispenserequest / dosageinstruction
--     before building at another site.
--   * The first-element picks (coding[1], doseAndRate[1]) take the first
--     entry Epic sent. Route can carry an Epic urn:oid coding ahead of the
--     SNOMED one - dosage_route_text is the stable human label.
-- ============================================================================
CREATE TABLE {{ prefix }}__medicationrequest AS
WITH
-- coverage_max_days: one prescription cycle. supply_days_total never exceeds
-- it, however many refills the order allows. Supply sentinels (0, 999, 9999)
-- are turned to NULL in the request CTE below.
params AS (
    SELECT 365 AS coverage_max_days
),

-- One row per request x dosage instruction step. A plain order has one step,
-- a taper has several, each with its own sequence, bounds and dose.
dosage_step AS (
    SELECT  mr.id,
            COALESCE(step.dosage."sequence", 1)                     AS dosage_sequence,
            step.dosage."text"                                      AS dosage_text,
            step.dosage."patientInstruction"                        AS dosage_patient_instruction,
            step.dosage."asNeededBoolean"                           AS dosage_as_needed_bool,
            step.dosage."route"."coding"[1]."code"                  AS dosage_route_code,
            step.dosage."route"."coding"[1]."system"                AS dosage_route_system,
            step.dosage."route"."text"                              AS dosage_route_text,
            step.dosage."timing"."code"."text"                      AS dosage_timing_text,
            step.dosage."timing"."repeat"."frequency"               AS dosage_frequency,
            step.dosage."timing"."repeat"."period"                  AS dosage_period,
            step.dosage."timing"."repeat"."periodUnit"              AS dosage_period_unit,
            DATE(SUBSTR(step.dosage."timing"."repeat"."boundsPeriod"."start", 1, 10))
                                                                    AS dosage_bounds_start_date,
            DATE(SUBSTR(step.dosage."timing"."repeat"."boundsPeriod"."end", 1, 10))
                                                                    AS dosage_bounds_end_date,
            step.dosage."doseAndRate"[1]."doseQuantity"."value"     AS dosage_dose_value,
            step.dosage."doseAndRate"[1]."doseQuantity"."unit"      AS dosage_dose_unit
    FROM    medicationrequest AS mr
    CROSS JOIN
            UNNEST(mr."dosageInstruction") AS step (dosage)
),

-- Earliest step wins - lowest sequence, then earliest bounds start, then text.
dosage_step_ranked AS (
    SELECT  dosage_step.*,
            ROW_NUMBER() OVER (
                PARTITION BY id
                ORDER BY dosage_sequence, dosage_bounds_start_date, dosage_text
            ) AS rn
    FROM    dosage_step
),

dosage_first AS (
    SELECT  *
    FROM    dosage_step_ranked
    WHERE   rn = 1
),

-- Order-level view across every step: the taper end date is the latest bounds end.
dosage_summary AS (
    SELECT  id,
            COUNT(*)                        AS dosage_count,
            MIN(dosage_bounds_start_date)   AS dosage_start_date,
            MAX(dosage_bounds_end_date)     AS dosage_end_date
    FROM    dosage_step
    GROUP BY id
),

-- Request-level elements, one row per raw MedicationRequest id.
request AS (
    SELECT  mr.id,
            mr."courseOfTherapyType"."coding"[1]."code"             AS course_of_therapy_code,
            mr."courseOfTherapyType"."coding"[1]."system"           AS course_of_therapy_system,
            mr."courseOfTherapyType"."coding"[1]."display"          AS course_of_therapy_display,
            mr."courseOfTherapyType"."text"                         AS course_of_therapy_text,
            mr."statusReason"."coding"[1]."code"                    AS status_reason_code,
            mr."statusReason"."coding"[1]."system"                  AS status_reason_system,
            mr."statusReason"."coding"[1]."display"                 AS status_reason_display,
            mr."statusReason"."text"                                AS status_reason_text,
            mr."priorPrescription"."reference"                      AS prior_prescription_ref,
            DATE(SUBSTR(mr."dispenseRequest"."validityPeriod"."start", 1, 10))
                                                                    AS dispense_validity_start_date,
            DATE(SUBSTR(mr."dispenseRequest"."validityPeriod"."end", 1, 10))
                                                                    AS dispense_validity_end_date,
            mr."dispenseRequest"."numberOfRepeatsAllowed"           AS dispense_refills_allowed,
            mr."dispenseRequest"."quantity"."value"                 AS dispense_quantity_value,
            mr."dispenseRequest"."quantity"."unit"                  AS dispense_quantity_unit,
            mr."dispenseRequest"."expectedSupplyDuration"."value"   AS expected_supply_duration_value,
            mr."dispenseRequest"."expectedSupplyDuration"."unit"    AS expected_supply_duration_unit,
            CASE
                WHEN mr."dispenseRequest"."expectedSupplyDuration"."value" <= 0
                  OR mr."dispenseRequest"."expectedSupplyDuration"."value" IN (999, 9999)
                THEN NULL
                WHEN LOWER(mr."dispenseRequest"."expectedSupplyDuration"."unit") IN ('d', 'day', 'days')
                THEN mr."dispenseRequest"."expectedSupplyDuration"."value"
                WHEN LOWER(mr."dispenseRequest"."expectedSupplyDuration"."unit") IN ('wk', 'week', 'weeks')
                THEN mr."dispenseRequest"."expectedSupplyDuration"."value" * 7
                WHEN LOWER(mr."dispenseRequest"."expectedSupplyDuration"."unit") IN ('mo', 'month', 'months')
                THEN mr."dispenseRequest"."expectedSupplyDuration"."value" * 30
                WHEN LOWER(mr."dispenseRequest"."expectedSupplyDuration"."unit") IN ('a', 'year', 'years')
                THEN mr."dispenseRequest"."expectedSupplyDuration"."value" * 365
            END                                                     AS expected_supply_days,
            DATE(SUBSTR(mr."authoredOn", 1, 10))                    AS authoredon_date
    FROM    medicationrequest AS mr
),

-- What the coverage interval is built from, one row per request. LEAST is
-- guarded because Trino and DuckDB disagree on LEAST with a NULL argument.
coverage_base AS (
    SELECT  request.id,
            CASE
                WHEN request.expected_supply_days IS NULL THEN NULL
                ELSE LEAST(
                    request.expected_supply_days
                        * (1 + COALESCE(request.dispense_refills_allowed, 0)),
                    params.coverage_max_days)
            END                                                         AS supply_days_total,
            COALESCE(dosage_summary.dosage_start_date, request.authoredon_date)
                                                                        AS coverage_start_date,
            dosage_summary.dosage_end_date
    FROM    request
    CROSS JOIN
            params
    LEFT JOIN dosage_summary
    ON      dosage_summary.id = request.id
),

coverage_supply AS (
    SELECT  coverage_base.*,
            DATE(coverage_start_date
                 + CAST(ROUND(supply_days_total) AS INTEGER) * INTERVAL '1' DAY)
                                                                        AS supply_end_date
    FROM    coverage_base
),

-- The earlier of the dosage bounds end and the supply end wins. LEAST is
-- guarded because Trino and DuckDB disagree on LEAST with a NULL argument.
coverage AS (
    SELECT  id,
            supply_days_total,
            coverage_start_date,
            supply_end_date,
            CASE
                WHEN dosage_end_date IS NULL THEN supply_end_date
                WHEN supply_end_date IS NULL THEN dosage_end_date
                ELSE LEAST(dosage_end_date, supply_end_date)
            END                                                         AS coverage_end_date,
            CASE
                WHEN dosage_end_date IS NOT NULL
                 AND (supply_end_date IS NULL OR dosage_end_date <= supply_end_date)
                THEN 'DOSAGE_BOUNDS_END'
                WHEN supply_end_date IS NOT NULL
                THEN 'SUPPLY_END'
            END                                                         AS coverage_end_date_type
    FROM    coverage_supply
)

SELECT  rx.id,
        rx.status,
        rx.intent,
        rx.category_code,
        rx.category_system,
        rx.category_display,
        rx.reportedboolean,
        rx.reported_ref,
        rx.medication_code,
        rx.medication_system,
        rx.medication_display,
        rx.authoredon,
        rx.authoredon_month,
        rx.medicationrequest_ref,
        rx.subject_ref,
        rx.encounter_ref,
        rx.requester_ref,

        request.course_of_therapy_code,
        request.course_of_therapy_system,
        request.course_of_therapy_display,
        request.course_of_therapy_text,

        request.status_reason_code,
        request.status_reason_system,
        request.status_reason_display,
        request.status_reason_text,

        request.prior_prescription_ref,

        COALESCE(dosage_summary.dosage_count, 0)    AS dosage_count,
        dosage_summary.dosage_start_date,
        dosage_summary.dosage_end_date,
        dosage_first.dosage_text,
        dosage_first.dosage_patient_instruction,
        dosage_first.dosage_as_needed_bool,
        dosage_first.dosage_route_code,
        dosage_first.dosage_route_system,
        dosage_first.dosage_route_text,
        dosage_first.dosage_timing_text,
        dosage_first.dosage_frequency,
        dosage_first.dosage_period,
        dosage_first.dosage_period_unit,
        dosage_first.dosage_dose_value,
        dosage_first.dosage_dose_unit,

        request.dispense_validity_start_date,
        request.dispense_validity_end_date,
        request.dispense_refills_allowed,
        request.dispense_quantity_value,
        request.dispense_quantity_unit,
        request.expected_supply_duration_value,
        request.expected_supply_duration_unit,

        request.expected_supply_days,
        coverage.supply_days_total,
        coverage.coverage_start_date,
        coverage.supply_end_date,
        coverage.coverage_end_date,
        coverage.coverage_end_date_type
FROM    core__medicationrequest AS rx
JOIN    request
ON      request.id = rx.id
JOIN    coverage
ON      coverage.id = rx.id
LEFT JOIN dosage_summary
ON      dosage_summary.id = rx.id
LEFT JOIN dosage_first
ON      dosage_first.id = rx.id
;
