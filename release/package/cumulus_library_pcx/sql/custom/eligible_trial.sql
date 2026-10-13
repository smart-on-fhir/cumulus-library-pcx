--  =====================================================================
--  Trial-like cohort: the strict intersection of the ACNS0334 criteria that
--  are structurally evaluable today. Organ-function criteria are not applied
--  (see registry_eligibility and laboratory tasks). A NULL criterion excludes
--  the subject here, which is the conservative choice for a trial emulation.
--  The prior-to-t0 flags are NULL without a t0, so no t0 means not eligible.
--
--  pcx__eligible keeps every subject and carries these criteria as flags.
--  ACNS0334 excludes ANY prior chemotherapy, so prior methotrexate excludes
--  here the same way the six backbone agents do.
--  =====================================================================
CREATE  TABLE   pcx__eligible_trial AS
SELECT  *
FROM    pcx__eligible
WHERE   (medulloblastoma_tier1_bool OR llm_medulloblastoma_bool)
AND     age_under_36_months_at_definitive_surgery
AND     NOT atrt_confirmed_bool
AND     NOT chemo_prior_to_t0_bool
AND     NOT methotrexate_prior_to_t0_bool
AND     NOT radiation_prior_to_t0_bool
;