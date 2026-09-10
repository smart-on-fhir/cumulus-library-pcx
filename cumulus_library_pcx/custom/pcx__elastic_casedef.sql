CREATE  TABLE   pcx__elastic_casedef AS
SELECT  DISTINCT
        elastic.topic,
        casedef.group_name,
        casedef.note_ref,
        casedef.fhir_resource,
        casedef.note_code,
        casedef.note_display,
        casedef.note_ordinal,
        casedef.sort_by_date,
        casedef.note_author_date,
        casedef.note_date,
        casedef.days_since,
        casedef.enc_period_start_day_min,
        casedef.enc_period_start_day,
        casedef.subject_ref,
        casedef.encounter_ref_link
FROM    pcx__sample_casedef     AS casedef
JOIN    pcx__elastic_union      AS elastic
ON      casedef.note_ref = elastic.note_ref
;