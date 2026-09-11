CREATE TABLE pcx__llm_systemic_therapy_stem_cell_infusion AS
SELECT  DISTINCT
        nlp.note_ref,
        nlp.encounter_ref,
        nlp.subject_ref,
        'pcx__nlp_systemic_therapy_gpt_oss_120b' AS origin,
        CAST(nlp.generated_on AS VARCHAR) AS generated_on,
        CAST(nlp.task_version AS BIGINT) AS task_version,
        nlp.system_fingerprint,
        -- 1-based position of each unnested list item (see FROM)
        stem_cell_infusion_index,
        -- mention values only: spans and has_mention stay in the source nlp table
        stem_cell_infusion.delivery_status                           AS delivery_status,
        stem_cell_infusion.phase                                     AS phase,
        stem_cell_infusion.infusion_date                             AS infusion_date,
        stem_cell_infusion.infusion_date_precision                   AS infusion_date_precision,
        stem_cell_infusion.cycle_name                                AS cycle_name,
        stem_cell_infusion.cell_source                               AS cell_source,
        stem_cell_infusion.cd34_cells_per_kg                         AS cd34_cells_per_kg
FROM
        pcx__nlp_systemic_therapy_gpt_oss_120b AS nlp
CROSS JOIN UNNEST(nlp.result.stem_cell_infusions) WITH ORDINALITY AS stem_cell_infusion_t (stem_cell_infusion, stem_cell_infusion_index)
WHERE
        nlp.result IS NOT NULL
AND     nlp.task_version = 1
