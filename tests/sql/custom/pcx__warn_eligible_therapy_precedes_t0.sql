-- ============================================================================
-- Warning: treatment evidence dated before time zero.
--
-- pcx__eligible turns chemo_prior_to_t0_bool / radiation_prior_to_t0_bool
-- into no_prior_chemotherapy_bool = FALSE / no_prior_radiation_bool = FALSE,
-- which removes the subject from pcx__eligible_trial. That is correct for a
-- child treated elsewhere before referral, and wrong when t0_day simply lags
-- the real diagnosis (see pcx__warn_eligible_t0_after_condition_date). Small
-- gaps (a chemo order authored a few days before the coded diagnosis
-- encounter) are almost always the second case.
-- ============================================================================
CREATE TABLE pcx__warn_eligible_therapy_precedes_t0 AS

WITH exposure AS (
    SELECT  rx.subject_ref,
            rx.t0_day,
            'chemo'                             AS exposure,
            rx.chemo_first_day                  AS exposure_day,
            CASE
                WHEN rx.chemo_administered_first_day = rx.chemo_first_day    THEN 'llm_administered'
                ELSE                                                              'rx_order'
            END                                 AS source
    FROM    pcx__eligible_rx AS rx
    WHERE   rx.chemo_first_day < rx.t0_day

    UNION ALL

    SELECT  rx.subject_ref,
            rx.t0_day,
            'methotrexate'                      AS exposure,
            rx.methotrexate_first_day           AS exposure_day,
            CASE
                WHEN rx.methotrexate_administered_first_day = rx.methotrexate_first_day THEN 'llm_administered'
                ELSE                                                                         'rx_order'
            END                                 AS source
    FROM    pcx__eligible_rx AS rx
    WHERE   rx.methotrexate_first_day < rx.t0_day

    UNION ALL

    SELECT  radiation.subject_ref,
            radiation.t0_day,
            'radiation'                         AS exposure,
            radiation.radiation_first_day       AS exposure_day,
            CASE
                WHEN radiation.radiation_administered_first_day = radiation.radiation_first_day  THEN 'llm_administered'
                WHEN radiation.radiation_proc_first_day         = radiation.radiation_first_day  THEN 'proc_radiation'
                ELSE                                                                                  'dx_radiation'
            END                                 AS source
    FROM    pcx__eligible_radiation AS radiation
    WHERE   radiation.radiation_first_day < radiation.t0_day
)

SELECT  CONCAT(exposure, '_precedes_t0')                                        AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('first=',    CAST(exposure_day AS VARCHAR)),
            CONCAT('t0=',       CAST(t0_day AS VARCHAR)),
            CONCAT('days=',     CAST(DATE_DIFF('day', exposure_day, t0_day) AS VARCHAR)),
            CONCAT('source=',   source))                                        AS detail
FROM    exposure
;
