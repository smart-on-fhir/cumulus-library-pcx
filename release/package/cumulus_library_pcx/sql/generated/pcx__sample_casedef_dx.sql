CREATE  TABLE   pcx__sample_casedef_dx AS
SELECT  DISTINCT
        c.subject_ref, c.note_ordinal, c.days_since, c.note_ref, c.group_name
FROM    pcx__sample_casedef                        as c
JOIN    pcx__cohort_variable_union_dx    as v
ON      c.encounter_ref_link = v.encounter_ref_link
AND     c.subject_ref = v.subject_ref
;


