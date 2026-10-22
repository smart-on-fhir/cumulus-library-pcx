--  =====================================================================
--  Exposure records: one row per piece of treatment evidence
--
--  The candidate evidence that pcx__eligible_rx, pcx__eligible_radiation and
--  pcx__outcome_exposure all read, each with the range of days it can fall on:
--    exposure      methotrexate (any LLM-administered methotrexate or ACNS0334
--                  Regimen B), methotrexate_structured (orders and dispenses,
--                  evidence only), chemo, radiation
--    source        rx_order, rx_dispense, proc_radiation, dx_radiation,
--                  llm_administered, llm_acns0334_regimen_b
--    exposure_day  the day as recorded, the first day of a month or year date
--    earliest_day / latest_day  the range the treatment can fall on:
--                  DAY      the day itself
--                  MONTH    the whole month, YEAR the whole year
--                  undated  no earliest day, and the latest day is the date
--                           of the note that mentions it (pcx__llm_note_date,
--                           FHIR metadata), since a note describes treatment
--                           already given. NULL when the note has no date.
--  A dose joins its agent, and an administration its regimen, within the same
--  extraction output: note_ref, generated_on and the array positions. A note
--  run twice has two outputs whose positions can name different drugs.
--    restated_bool an undated mention when a dated record of the same
--                  exposure falls on or before its note date: a restatement
--                  of treatment already on record, ignored for timing
--  Methotrexate: the CHOP clinical team treats any methotrexate given to these
--  patients as high-dose (2026-10-22). Chemotherapy is the six backbone agents
--  (orders and dispenses) and every LLM-administered agent except the
--  supportive markers LEUCOVORIN, MESNA and DEXRAZOXANE. Radiation is tier 1
--  procedure and encounter codes and LLM-administered rounds.
--  =====================================================================
CREATE  TABLE   pcx__exposure_record AS
WITH
rx_valueset AS (
    SELECT  'methotrexate_structured' AS exposure, "system", code FROM pcx__valueset_rx_contrast_methotrexate
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_carboplatin
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_cisplatin
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_cyclophosphamide
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_etoposide
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_thiotepa
    UNION ALL
    SELECT  'chemo', "system", code FROM pcx__valueset_rx_chemo_vincristine
),
-- every LLM administration, at the agent level and at the dose level
llm_administered AS (
    SELECT  subject_ref,
            note_ref,
            generated_on,
            regimen_index,
            agent_name,
            therapy_start_day                       AS exposure_day,
            therapy_start_day_precision             AS day_precision,
            CAST(NULL AS BOOLEAN)                   AS high_dose_bool,
            CAST(NULL AS VARCHAR)                   AS route
    FROM    pcx__llm_systemic_therapy_agent
    WHERE   delivery_status = 'ADMINISTERED'
    UNION ALL
    SELECT  dose.subject_ref,
            dose.note_ref,
            dose.generated_on,
            dose.regimen_index,
            agent.agent_name,
            dose.administration_day,
            dose.administration_day_precision,
            dose.high_dose_methotrexate_explicit_bool,
            dose.route
    FROM    pcx__llm_systemic_therapy_administration    AS dose
    JOIN    pcx__llm_systemic_therapy_agent             AS agent
    ON      agent.note_ref      = dose.note_ref
    AND     agent.generated_on  = dose.generated_on
    AND     agent.regimen_index = dose.regimen_index
    AND     agent.agent_index   = dose.agent_index
    WHERE   dose.delivery_status = 'ADMINISTERED'
),
regimen_b AS (
    SELECT  subject_ref,
            note_ref,
            generated_on,
            regimen_index,
            regimen_start_day,
            regimen_start_day_precision
    FROM    pcx__llm_systemic_therapy_regimen
    WHERE   protocol_name = 'ACNS0334'
    AND     documented_trial_arm = 'REGIMEN_B'
),
candidate AS (
    SELECT  subject_ref,
            'methotrexate_structured'   AS exposure,
            'rx_order'                  AS source,
            CAST(NULL AS VARCHAR)       AS note_ref,
            rx_authoredon_date          AS exposure_day,
            'DAY'                       AS day_precision,
            CAST(NULL AS BOOLEAN)       AS high_dose_bool,
            CAST(NULL AS VARCHAR)       AS route
    FROM    pcx__cohort_variable_union_rx
    WHERE   variable = 'rx_contrast_methotrexate'
    UNION ALL
    SELECT  subject_ref, 'chemo', 'rx_order', NULL, rx_authoredon_date, 'DAY', NULL, NULL
    FROM    pcx__cohort_variable_union_rx
    WHERE   variable LIKE 'rx_chemo_%'
    UNION ALL
    -- core__medicationdispense already drops entered-in-error
    SELECT  md.subject_ref, rx_valueset.exposure, 'rx_dispense', NULL, md.whenhandedover_day, 'DAY', NULL, NULL
    FROM    core__medicationdispense    AS md
    JOIN    rx_valueset
    ON      rx_valueset."system" = md.medication_system
    AND     rx_valueset.code = md.medication_code
    WHERE   md.whenhandedover_day IS NOT NULL
    AND     md.status NOT IN ('cancelled', 'declined')
    UNION ALL
    SELECT  subject_ref, 'methotrexate', 'llm_administered', note_ref, exposure_day, day_precision, high_dose_bool, route
    FROM    llm_administered
    WHERE   agent_name = 'METHOTREXATE'
    UNION ALL
    SELECT  subject_ref, 'methotrexate', 'llm_acns0334_regimen_b', note_ref, regimen_start_day,
            regimen_start_day_precision, NULL, NULL
    FROM    regimen_b
    UNION ALL
    SELECT  administered.subject_ref, 'methotrexate', 'llm_acns0334_regimen_b', administered.note_ref,
            administered.exposure_day, administered.day_precision, NULL, NULL
    FROM    llm_administered    AS administered
    JOIN    regimen_b
    ON      regimen_b.note_ref      = administered.note_ref
    AND     regimen_b.generated_on  = administered.generated_on
    AND     regimen_b.regimen_index = administered.regimen_index
    WHERE   administered.agent_name = 'METHOTREXATE'
    UNION ALL
    SELECT  subject_ref, 'chemo', 'llm_administered', note_ref, exposure_day, day_precision, NULL, NULL
    FROM    llm_administered
    WHERE   agent_name NOT IN ('LEUCOVORIN', 'MESNA', 'DEXRAZOXANE')
    UNION ALL
    SELECT  subject_ref, 'radiation', 'proc_radiation', NULL, proc_performed_day, 'DAY', NULL, NULL
    FROM    pcx__cohort_proc_radiation
    WHERE   CAST(tier AS INTEGER) = 1
    UNION ALL
    SELECT  subject_ref, 'radiation', 'dx_radiation', NULL, dx_recorded_date, 'DAY', NULL, NULL
    FROM    pcx__cohort_dx_radiation
    WHERE   CAST(tier AS INTEGER) = 1
    UNION ALL
    SELECT  subject_ref, 'radiation', 'llm_administered', note_ref, radiation_start_day,
            radiation_start_day_precision, NULL, NULL
    FROM    pcx__llm_radiation_wide
    WHERE   delivery_status = 'ADMINISTERED'
),
ranged AS (
    SELECT  candidate.subject_ref,
            candidate.exposure,
            candidate.source,
            candidate.note_ref,
            candidate.exposure_day,
            CASE WHEN candidate.exposure_day IS NOT NULL THEN candidate.day_precision END  AS day_precision,
            candidate.exposure_day                                                          AS earliest_day,
            CASE
                WHEN candidate.exposure_day IS NULL         THEN note_day.note_date
                WHEN candidate.day_precision = 'MONTH'      THEN CAST(candidate.exposure_day + INTERVAL '1' MONTH - INTERVAL '1' DAY AS DATE)
                WHEN candidate.day_precision = 'YEAR'       THEN CAST(candidate.exposure_day + INTERVAL '1' YEAR - INTERVAL '1' DAY AS DATE)
                ELSE                                             candidate.exposure_day
            END                                                                             AS latest_day,
            candidate.high_dose_bool,
            candidate.route
    FROM    candidate
    LEFT JOIN pcx__llm_note_date AS note_day
      ON    note_day.subject_ref = candidate.subject_ref
     AND    note_day.note_ref    = candidate.note_ref
),
dated_first AS (
    SELECT  subject_ref,
            exposure,
            MIN(earliest_day)   AS dated_first_day
    FROM    ranged
    WHERE   earliest_day IS NOT NULL
    GROUP BY subject_ref, exposure
)
SELECT  ranged.*,
        CASE
            WHEN ranged.earliest_day IS NULL
             AND dated_first.dated_first_day <= ranged.latest_day                    THEN TRUE
            ELSE                                                                          FALSE
        END                                                                         AS restated_bool
FROM    ranged
LEFT JOIN dated_first
  ON    dated_first.subject_ref = ranged.subject_ref
 AND    dated_first.exposure    = ranged.exposure
;
