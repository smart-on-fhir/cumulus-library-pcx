-- Inline codings (MedicationDispense.medicationCodeableConcept). Epic mostly
-- sends medicationReference instead, so this is often empty.

CREATE  TABLE {{ prefix }}__medicationdispense_dn_inline_code AS
SELECT  DISTINCT
        md.id,
        t.coding.code           AS code,
        t.coding."system"       AS "system",
        t.coding.display        AS display,
        t.coding."userSelected" AS "userSelected"
FROM    medicationdispense AS md
CROSS JOIN
        UNNEST(md."medicationCodeableConcept".coding) AS t (coding)
;

