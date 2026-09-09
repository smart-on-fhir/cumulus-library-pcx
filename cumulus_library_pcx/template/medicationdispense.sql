-- ============================================================================
-- Grain: one row per MedicationDispense id x medication coding.
--
-- Purpose: the fill - what the pharmacy actually handed over and when. Mirrors
--        cumulus core's MedicationRequest shape (which core does not provide
--        for MedicationDispense) and adds the fill-level elements the study
--        needs: days supply, quantity, first-fill vs refill type, category,
--        the authorizing MedicationRequest, and the coverage interval the
--        fill implies (whenHandedOver plus days supply).
--
-- Sources: medicationdispense (raw Cumulus ETL), core__medication_dn_code
--        (cumulus core, resolves Medication references to codes)
-- Docs:    schema.md, "Table layers"
--
-- Notes:
--   * Epic MedicationDispense comes from its own pharmacy system, so this is
--     where infusion-center and inpatient dispensing appears - the doses that
--     are nearly invisible as community orders.
--   * days_supply_value is normalised to days_supply_days the same way
--     prefix__medicationrequest normalises expectedSupplyDuration.
-- ============================================================================
CREATE  TABLE {{ prefix }}__medicationdispense AS
WITH
-- coverage_max_days: same one-cycle cap as prefix__medicationrequest. Fill days
-- supply sentinels (0, 999, 9999) become NULL below.
params AS (
    SELECT 365 AS coverage_max_days
),

md_basics AS (
    SELECT  DISTINCT
            md.id,
            md.status,
            md."medicationReference".reference          AS med_ref,
            md.subject.reference                        AS subject_ref,
            md.context.reference                        AS encounter_ref,
            CAST(from_iso8601_timestamp(md."whenHandedOver") AS timestamp)
                                                        AS "whenHandedOver",
            DATE(SUBSTR(md."whenHandedOver", 1, 10))    AS whenhandedover_date,
            DATE(SUBSTR(md."whenPrepared", 1, 10))      AS whenprepared_date,
            md."type".coding[1].code                    AS type_code,
            md."type".coding[1].display                 AS type_display,
            md.category.coding[1].code                  AS category_code,
            md."authorizingPrescription"[1].reference   AS medicationrequest_ref,
            md.quantity.value                           AS quantity_value,
            md.quantity.unit                            AS quantity_unit,
            md."daysSupply".value                       AS days_supply_value,
            md."daysSupply".unit                        AS days_supply_unit,
            CASE
                WHEN md."daysSupply".value IS NULL
                  OR md."daysSupply".value <= 0
                  OR md."daysSupply".value IN (999, 9999)
                THEN NULL
                WHEN LOWER(md."daysSupply".unit) IN ('d', 'day', 'days')
                THEN LEAST(md."daysSupply".value, params.coverage_max_days)
                WHEN LOWER(md."daysSupply".unit) IN ('wk', 'week', 'weeks')
                THEN LEAST(md."daysSupply".value * 7, params.coverage_max_days)
                WHEN LOWER(md."daysSupply".unit) IN ('mo', 'month', 'months')
                THEN LEAST(md."daysSupply".value * 30, params.coverage_max_days)
                WHEN LOWER(md."daysSupply".unit) IN ('a', 'year', 'years')
                THEN LEAST(md."daysSupply".value * 365, params.coverage_max_days)
            END                                         AS days_supply_days
    FROM    medicationdispense AS md
    CROSS JOIN
            params
    WHERE   (md.status IS NULL OR md.status <> 'entered-in-error')
),

contained_refs AS (
    SELECT  DISTINCT
            md.id,
            substring(md.med_ref, 2) AS medication_id
    FROM    md_basics AS md
    WHERE   md.med_ref IS NOT NULL
      AND   REGEXP_LIKE(md.med_ref, '^#.*$')
),

external_refs AS (
    SELECT  DISTINCT
            md.id,
            substring(md.med_ref, 12) AS medication_id
    FROM    md_basics AS md
    WHERE   md.med_ref IS NOT NULL
      AND   md.med_ref LIKE 'Medication/%'
),

unified_codes AS (
    -- Inline MedicationDispense.medicationCodeableConcept
    SELECT  md.id,
            mdic.code       AS medication_code,
            mdic."system"   AS medication_system,
            mdic.display    AS medication_display
    FROM    md_basics AS md
    JOIN    {{ prefix }}__medicationdispense_dn_inline_code AS mdic
    ON      md.id = mdic.id

    UNION

    -- Medication resource contained within MedicationDispense
    SELECT  md.id,
            mdcc.code       AS medication_code,
            mdcc."system"   AS medication_system,
            mdcc.display    AS medication_display
    FROM    md_basics AS md
    JOIN    contained_refs AS cr
    ON      md.id = cr.id
    JOIN    {{ prefix }}__medicationdispense_dn_contained_code AS mdcc
    ON      cr.id = mdcc.id
    AND     cr.medication_id = mdcc.contained_id
    WHERE   mdcc.resource_type = 'Medication'

    UNION

    -- External Medication reference, resolved by cumulus core
    SELECT  md.id,
            mc.code         AS medication_code,
            mc."system"     AS medication_system,
            mc.display      AS medication_display
    FROM    md_basics AS md
    JOIN    external_refs AS er
    ON      md.id = er.id
    JOIN    core__medication_dn_code AS mc
    ON      er.medication_id = mc.id
)

SELECT  md.id,
        md.status,
        md.med_ref                                  AS medication_ref,
        uc.medication_code,
        uc.medication_system,
        uc.medication_display,
        md."whenHandedOver",
        md.whenhandedover_date,
        md.whenprepared_date,
        md.type_code,
        md.type_display,
        md.category_code,
        md.quantity_value,
        md.quantity_unit,
        md.days_supply_value,
        md.days_supply_unit,
        md.days_supply_days,
        DATE(md.whenhandedover_date
             + CAST(ROUND(md.days_supply_days) AS INTEGER) * INTERVAL '1' DAY)
                                                    AS supply_end_date,
        concat('MedicationDispense/', md.id)        AS medicationdispense_ref,
        md.medicationrequest_ref,
        md.subject_ref,
        md.encounter_ref
FROM    md_basics AS md
LEFT JOIN
        unified_codes AS uc
ON      md.id = uc.id
;
