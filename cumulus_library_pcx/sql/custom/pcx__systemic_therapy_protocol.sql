--  =====================================================================
--  Systemic therapy protocol: one row per LLM regimen mention, with its
--  protocol resolved through spreadsheet/include_trial_protocol.csv
--  (pcx__include_trial_protocol: protocol_name, protocol_name_verbatim).
--
--  protocol_name is, in order:
--    1. the sheet's protocol_name when protocol_name_verbatim equals a listed
--       verbatim, ignoring case. DFCI 07-308 is the Dana-Farber local number
--       for ACNS0334, so "DFCI 07-308, regimen B" is ACNS0334 even when the
--       LLM coded NONE_OF_THE_ABOVE or another protocol (HeadStart II (07-308)).
--    2. otherwise the LLM's coded protocol_name.
--  protocol_name_llm keeps the LLM's coded value for review.
--  Everything that reads ACNS0334 or its documented_trial_arm reads this
--  table, not pcx__llm_systemic_therapy_regimen: the ACNS0334 Regimen B
--  methotrexate exposure (pcx__exposure_record), the Kaplan protocol and arm
--  labels (pcx__kaplan_subject) and the strict Kaplan cohort, which keeps the
--  protocols listed in the sheet (pcx__kaplan_subject_strict).
--  A verbatim listed under two protocols would duplicate regimen rows, so each
--  verbatim maps to one protocol, ignoring case (tests check it).
--  =====================================================================
CREATE  TABLE   pcx__systemic_therapy_protocol AS
WITH
listed AS (
    SELECT  DISTINCT
            LOWER(protocol_name_verbatim)   AS verbatim_lower,
            protocol_name
    FROM    pcx__include_trial_protocol
)
SELECT  regimen.subject_ref,
        regimen.note_ref,
        regimen.generated_on,
        regimen.regimen_index,
        COALESCE(listed.protocol_name, regimen.protocol_name)  AS protocol_name,
        regimen.protocol_name                                  AS protocol_name_llm,
        regimen.protocol_name_verbatim,
        regimen.documented_trial_arm,
        regimen.regimen_start_day,
        regimen.regimen_start_day_precision
FROM    pcx__llm_systemic_therapy_regimen AS regimen
LEFT JOIN listed
  ON    listed.verbatim_lower = LOWER(regimen.protocol_name_verbatim)
;
