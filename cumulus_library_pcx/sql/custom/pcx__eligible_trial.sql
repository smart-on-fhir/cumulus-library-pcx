--  =====================================================================
--  Trial-like cohort: the strict intersection of the ACNS0334 criteria that
--  are structurally evaluable today. Organ-function criteria are not applied
--  (see registry_eligibility and laboratory tasks). A NULL criterion excludes
--  the subject here, which is the conservative choice for a trial emulation.
--  =====================================================================
CREATE  TABLE   pcx__eligible_trial AS
SELECT  *
FROM    pcx__eligible
WHERE   (medulloblastoma_tier1_bool OR llm_medulloblastoma_bool)
AND     age_under_36_months_at_definitive_surgery
AND     NOT atrt_confirmed_bool
AND     no_prior_chemotherapy_bool
AND     no_prior_radiation_bool
;