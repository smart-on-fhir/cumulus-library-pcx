-- ==========================================================================
-- Grain: one row per subject_ref x exposure (METHOTREXATE, CHEMOTHERAPY, RADIATION).
--
-- Long form of the treatment exposures the study compares. Every date comes
-- from pcx__eligible_rx / pcx__eligible_radiation and every first-event flag
-- from pcx__outcome_exposure, so this view adds no new rules. Subject-level
-- sequence and protocol names live on pcx__client_subject.
-- ==========================================================================
CREATE TABLE pcx__client_exposure AS
WITH
exposure AS (
    SELECT  rx.subject_ref,
            'METHOTREXATE'                          AS exposure,
            rx.methotrexate_first_day               AS first_day,
            rx.methotrexate_order_first_day         AS order_first_day,
            rx.methotrexate_administered_first_day  AS administered_first_day,
            rx.methotrexate_any_bool                AS any_bool,
            rx.methotrexate_administered_bool       AS administered_bool,
            (rx.methotrexate_first_day < rx.t0_day) AS prior_to_t0_bool,
            outcome.methotrexate_prior_to_first_event_bool AS prior_to_first_event_bool
    FROM    pcx__eligible_rx            AS rx
    LEFT JOIN pcx__outcome_exposure     AS outcome ON outcome.subject_ref = rx.subject_ref
    UNION ALL
    SELECT  rx.subject_ref,
            'CHEMOTHERAPY'                          AS exposure,
            rx.chemo_first_day,
            rx.chemo_order_first_day,
            rx.chemo_administered_first_day,
            rx.chemo_any_bool,
            (rx.chemo_administered_first_day IS NOT NULL),
            rx.chemo_prior_to_t0_bool,
            outcome.chemo_prior_to_first_event_bool
    FROM    pcx__eligible_rx            AS rx
    LEFT JOIN pcx__outcome_exposure     AS outcome ON outcome.subject_ref = rx.subject_ref
    UNION ALL
    SELECT  rt.subject_ref,
            'RADIATION'                             AS exposure,
            rt.radiation_first_day,
            rt.radiation_proc_first_day,
            rt.radiation_administered_first_day,
            rt.radiation_any_bool,
            rt.radiation_administered_bool,
            rt.radiation_prior_to_t0_bool,
            outcome.radiation_prior_to_first_event_bool
    FROM    pcx__eligible_radiation     AS rt
    LEFT JOIN pcx__outcome_exposure     AS outcome ON outcome.subject_ref = rt.subject_ref
)

SELECT  exposure.subject_ref,
        exposure.exposure,
        exposure.any_bool,
        exposure.administered_bool,
        exposure.first_day,
        exposure.order_first_day,
        exposure.administered_first_day,
        DATE_DIFF('day', subject.t0_day, exposure.first_day)    AS days_t0_to_first,
        exposure.prior_to_t0_bool,
        exposure.prior_to_first_event_bool
FROM    exposure
JOIN    pcx__client_subject AS subject
  ON    exposure.subject_ref = subject.subject_ref
;
