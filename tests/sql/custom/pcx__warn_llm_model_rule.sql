-- ============================================================================
-- Warning: an LLM answer that breaks a rule of its own model.
--
-- The model validators (@model_validator in llm/models/*.py) run only in the
-- tests. Cumulus Library rebuilds each model from its JSON schema, which cannot
-- carry Python checks, so at inference these answers are stored as given.
-- This table applies the checks to the stored answers instead.
--
--   administration_date_not_administered   a dose with an administration date whose
--                                          delivery_status is not ADMINISTERED
--   dose_unit_without_amount               a dose unit with no numeric dose
--   dose_amount_negative                   a negative dose
--   cycle_num_below_1                      a cycle number below 1 (dose, cycle or
--                                          stem-cell infusion)
--   cd34_negative                          a negative CD34+ cells/kg
--   death_date_not_deceased                a death date on a vital status that is
--                                          not DECEASED. outcome_vital_status still
--                                          takes the date as a death date
--   alive_after_death_in_note              last known alive after the death date
--                                          in the same note, both day precision
--
-- Evidence rules (a finding needs verbatim spans) are not checked here: the wide
-- tables do not carry has_mention or spans.
-- ============================================================================
CREATE TABLE pcx__warn_llm_model_rule AS

SELECT  'administration_date_not_administered'                                  AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',    'pcx__llm_systemic_therapy_administration'),
            CONCAT('date=',     administration_date),
            CONCAT('status=',   delivery_status),
            CONCAT('note=',     note_ref))                                      AS detail
FROM    pcx__llm_systemic_therapy_administration
WHERE   administration_date IS NOT NULL
AND     delivery_status <> 'ADMINISTERED'

UNION ALL

SELECT  'dose_unit_without_amount'                                              AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',    'pcx__llm_systemic_therapy_administration'),
            CONCAT('unit=',     dose_unit),
            CONCAT('note=',     note_ref))                                      AS detail
FROM    pcx__llm_systemic_therapy_administration
WHERE   dose_unit <> 'NONE_OF_THE_ABOVE'
AND     dose_amount IS NULL

UNION ALL

SELECT  'dose_amount_negative'                                                  AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',    'pcx__llm_systemic_therapy_administration'),
            CONCAT('dose=',     CAST(dose_amount AS VARCHAR)),
            CONCAT('note=',     note_ref))                                      AS detail
FROM    pcx__llm_systemic_therapy_administration
WHERE   dose_amount < 0

UNION ALL

SELECT  'cycle_num_below_1'                                                     AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',    source_table),
            CONCAT('cycle=',    CAST(cycle_num AS VARCHAR)),
            CONCAT('note=',     note_ref))                                      AS detail
FROM    (
    SELECT 'pcx__llm_systemic_therapy_administration' AS source_table, subject_ref, note_ref, cycle_num
    FROM   pcx__llm_systemic_therapy_administration
    UNION ALL
    SELECT 'pcx__llm_systemic_therapy_cycle', subject_ref, note_ref, cycle_num
    FROM   pcx__llm_systemic_therapy_cycle
    UNION ALL
    SELECT 'pcx__llm_systemic_therapy_stem_cell_infusion', subject_ref, note_ref, cycle_num
    FROM   pcx__llm_systemic_therapy_stem_cell_infusion
) AS cycle
WHERE   cycle_num < 1

UNION ALL

SELECT  'cd34_negative'                                                         AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',    'pcx__llm_systemic_therapy_stem_cell_infusion'),
            CONCAT('cd34=',     CAST(cd34_cells_per_kg AS VARCHAR)),
            CONCAT('note=',     note_ref))                                      AS detail
FROM    pcx__llm_systemic_therapy_stem_cell_infusion
WHERE   cd34_cells_per_kg < 0

UNION ALL

SELECT  'death_date_not_deceased'                                               AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',    'pcx__llm_survival_timeline_wide'),
            CONCAT('death=',    death_date),
            CONCAT('status=',   vital_status),
            CONCAT('note=',     note_ref))                                      AS detail
FROM    pcx__llm_survival_timeline_wide
WHERE   death_date IS NOT NULL
AND     vital_status <> 'DECEASED'

UNION ALL

SELECT  'alive_after_death_in_note'                                             AS warn_check,
        CAST(subject_ref AS VARCHAR)                                            AS subject_ref,
        CONCAT_WS('|',
            CONCAT('table=',        'pcx__llm_survival_timeline_wide'),
            CONCAT('death=',        CAST(death_day AS VARCHAR)),
            CONCAT('last_alive=',   CAST(last_known_alive_day AS VARCHAR)),
            CONCAT('note=',         note_ref))                                  AS detail
FROM    pcx__llm_survival_timeline_wide
WHERE   last_known_alive_day > death_day
AND     death_day_precision = 'DAY'
AND     last_known_alive_day_precision = 'DAY'
;
