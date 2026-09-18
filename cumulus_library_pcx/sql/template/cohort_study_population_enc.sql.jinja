CREATE  TABLE   {{ prefix }}__cohort_study_population_enc AS
SELECT DISTINCT
        -- priority
        enc.priority_system     AS enc_priority_system,
        enc.priority_code       AS enc_priority_code,
        enc.priority_display    AS enc_priority_display,

        -- reason for visit
        enc.reasoncode_system   AS enc_reasoncode_system,
        enc.reasoncode_code     AS enc_reasoncode_code,
        enc.reasoncode_display  AS enc_reasoncode_display,

        -- discharged disposition
        enc.dischargedisposition_system     AS enc_dischargedisposition_system,
        enc.dischargedisposition_code       AS enc_dischargedisposition_code,
        enc.dischargedisposition_display    AS enc_dischargedisposition_display,

        -- rollups if desired
        enc.period_start_week   AS enc_period_start_week,
        enc.period_start_month  AS enc_period_start_month,
        enc.period_start_year   AS enc_period_start_year,

        -- encounter metadata cols
        enc.class_code          AS enc_class_code,
        enc.class_display       AS enc_class_display,
        enc.servicetype_code    AS enc_servicetype_code,
        enc.servicetype_system  AS enc_servicetype_system,
        enc.servicetype_display AS enc_servicetype_display,
        enc.type_code           AS enc_type_code,
        enc.type_system         AS enc_type_system,
        enc.type_display        AS enc_type_display,

        -- study population linking
        study_population.*,

        -- encounter_ref_link for linking compatibility
        enc.encounter_ref       AS encounter_ref_link,
        'encounter_ref'         AS encounter_ref_link_col
FROM    {{ prefix }}__cohort_study_population   AS study_population
JOIN    core__encounter                         AS enc
ON      study_population.encounter_ref = enc.encounter_ref
;