CREATE  TABLE   pcx__elastic_union AS
WITH select_union AS
(
	SELECT  CAST(NULL AS VARCHAR) AS topic,
		CAST(NULL AS VARCHAR) AS subject_ref,
		CAST(NULL AS VARCHAR) AS encounter_ref,
		CAST(NULL AS VARCHAR) AS note_ref,
		CAST(NULL AS VARCHAR) AS group_name,
		CAST(NULL AS VARCHAR) AS document_title
	WHERE   FALSE
)
SELECT  DISTINCT *
FROM    select_union
;

