--  =====================================================================
--  Outcome: one row per eligible subject with OS and provisional EFS
--
--  OS (README section 3): origin t0_day, event = death, event day = death_day,
--  censor at last_known_alive_day. A deceased flag without a death day gives
--  os_event_bool TRUE and os_days NULL, never a substituted date.
--  EFS (README section 5, reach goal): event = event_documented_bool, which
--  includes events without a usable date. efs_censor_source says how the row ends:
--    first_event                   dated first event, efs_end_day = first_event_day
--    event_timing_uncertain        an undated progression, recurrence or second
--                                  malignancy that may precede the dated event (not a
--                                  restatement, see pcx__outcome_first_event). Event
--                                  TRUE, interval NULL until it is reconciled,
--                                  first_event_day kept as evidence.
--    event_undated                 the only event is a death without a date.
--                                  Event TRUE, interval NULL, the same rule as OS.
--    last_known_alive_provisional  no documented event. Censoring uses
--                                  last_known_alive_day as a PROVISIONAL stand-in
--                                  until dated event-free follow-up is adjudicated.
--  A month or year date is used at the middle of its period for durations:
--  os_end_day_imputed_bool / efs_end_day_imputed_bool say when the end day is.
--  =====================================================================
CREATE  TABLE   pcx__outcome AS
SELECT  eligible.subject_ref,
        eligible.gender,
        eligible.age_band_at_t0,
        eligible.age_months_at_t0,
        eligible.age_under_36_months_at_definitive_surgery,
        eligible.t0_day,
        -- overall survival
        vital.deceased_bool                     AS os_event_bool,
        vital.death_day,
        vital.last_known_alive_day,
        CASE
            WHEN    vital.deceased_bool
            THEN    vital.death_day
            ELSE    vital.last_known_alive_day  AS os_end_day,
        CASE
            WHEN    vital.deceased_bool
            THEN    DATE_DIFF('day', eligible.t0_day, vital.death_day)
            ELSE    DATE_DIFF('day', eligible.t0_day, vital.last_known_alive_day)
        END                                     AS os_days,
        CASE
            WHEN    vital.deceased_bool
            THEN    vital.death_day_imputed_bool
            ELSE    vital.last_known_alive_day_imputed_bool
        END                                     AS os_end_day_imputed_bool,
        -- event-free survival, provisional
        event.event_documented_bool             AS efs_event_bool,
        event.first_event_day,
        event.first_event_type,
        CASE
            WHEN    event.event_timing_uncertain_bool
            THEN    NULL
            WHEN    event.dated_event_bool
            THEN    event.first_event_day
            WHEN    event.death_undated_bool
            THEN    NULL
            ELSE    vital.last_known_alive_day
        END         AS efs_end_day,
        CASE
            WHEN    event.event_timing_uncertain_bool
            THEN    NULL
            WHEN    event.dated_event_bool
            THEN    DATE_DIFF('day', eligible.t0_day, event.first_event_day)
            WHEN    event.death_undated_bool
            THEN    NULL
            ELSE    DATE_DIFF('day', eligible.t0_day, vital.last_known_alive_day)
        END         AS efs_days,
        CASE
            WHEN    event.event_timing_uncertain_bool
            THEN    NULL
            WHEN    event.dated_event_bool
            THEN    event.first_event_day_imputed_bool
            WHEN    event.death_undated_bool
            THEN    NULL
            ELSE    vital.last_known_alive_day_imputed_bool
        END         AS efs_end_day_imputed_bool,
        CASE
            WHEN    event.event_timing_uncertain_bool
            THEN    'event_timing_uncertain'
            WHEN    event.dated_event_bool
            THEN    'first_event'
            WHEN    event.death_undated_bool
            THEN    'event_undated'
            ELSE    'last_known_alive_provisional'
        END         AS efs_censor_source,
        -- exposures as initial therapy
        exposure.had_initial_methotrexate_bool,
        exposure.had_initial_chemo_bool,
        exposure.had_initial_radiation_bool,
        exposure.initial_therapy_sequence,
        exposure.protocol_names,
        exposure.methotrexate_first_day,
        exposure.chemo_first_day,
        exposure.radiation_first_day
FROM    pcx__eligible                  AS eligible
LEFT JOIN pcx__outcome_vital_status    AS vital    ON vital.subject_ref    = eligible.subject_ref
LEFT JOIN pcx__outcome_first_event     AS event    ON event.subject_ref    = eligible.subject_ref
LEFT JOIN pcx__outcome_exposure        AS exposure ON exposure.subject_ref = eligible.subject_ref
;