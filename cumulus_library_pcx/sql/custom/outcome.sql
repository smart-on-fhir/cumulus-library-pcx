--  =====================================================================
--  Outcome: one row per eligible subject with OS and provisional EFS
--
--  OS (README section 3): origin t0_day, event = death, event day = death_day,
--  censor at last_known_alive_day. A deceased flag without a death day gives
--  os_event_bool TRUE and os_days NULL, never a substituted date.
--  EFS (README section 5, reach goal): event = first_event_day. Censoring uses
--  last_known_alive_day as a PROVISIONAL stand-in until dated event-free
--  follow-up is adjudicated, so efs_censor_source says so on every row.
--  =====================================================================
CREATE  TABLE   pcx__outcome AS
SELECT  elig.subject_ref,
        elig.gender,
        elig.age_band_at_t0,
        elig.age_months_at_t0,
        elig.age_under_36_months_at_definitive_surgery,
        elig.t0_day,
        -- overall survival
        vital.deceased_bool                                                 AS os_event_bool,
        vital.death_day,
        vital.last_known_alive_day,
        CASE
            WHEN vital.deceased_bool    THEN vital.death_day
            ELSE                             vital.last_known_alive_day
        END                                                                 AS os_end_day,
        CASE
            WHEN vital.deceased_bool    THEN DATE_DIFF('day', elig.t0_day, vital.death_day)
            ELSE                             DATE_DIFF('day', elig.t0_day, vital.last_known_alive_day)
        END                                                                 AS os_days,
        -- event-free survival, provisional
        event.any_event_bool                                                AS efs_event_bool,
        event.first_event_day,
        event.first_event_type,
        CASE
            WHEN event.any_event_bool   THEN event.first_event_day
            ELSE                             vital.last_known_alive_day
        END                                                                 AS efs_end_day,
        CASE
            WHEN event.any_event_bool   THEN DATE_DIFF('day', elig.t0_day, event.first_event_day)
            ELSE                             DATE_DIFF('day', elig.t0_day, vital.last_known_alive_day)
        END                                                                 AS efs_days,
        CASE
            WHEN event.any_event_bool   THEN 'first_event'
            ELSE                             'last_known_alive_provisional'
        END                                                                 AS efs_censor_source,
        -- exposures as initial therapy
        exposure.methotrexate_prior_to_first_event_bool,
        exposure.radiation_prior_to_first_event_bool,
        exposure.initial_therapy_sequence,
        exposure.protocol_names,
        exposure.methotrexate_first_day,
        exposure.chemo_first_day,
        exposure.radiation_first_day
FROM    pcx__eligible                  AS elig
LEFT JOIN pcx__outcome_vital_status    AS vital    ON vital.subject_ref    = elig.subject_ref
LEFT JOIN pcx__outcome_first_event     AS event    ON event.subject_ref    = elig.subject_ref
LEFT JOIN pcx__outcome_exposure        AS exposure ON exposure.subject_ref = elig.subject_ref
;