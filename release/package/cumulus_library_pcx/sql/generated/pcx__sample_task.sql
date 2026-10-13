CREATE  TABLE   pcx__sample_task AS
SELECT  DISTINCT
        'casedef' as topic,
        subject_ref,
        note_ref,
        group_name,
        note_display
FROM    pcx__sample_casedef
UNION ALL
SELECT  DISTINCT
        topic,
        subject_ref,
        note_ref,
        group_name,
        document_title as note_display
FROM    pcx__elastic_union
;