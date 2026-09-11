-- ============================================================================
-- Grain: one row per pcx__client_timeline.variable observed at this site.
--
-- The census, not the schema. spreadsheet/client_dictionary.csv is the
-- authored dictionary: it says which variables EXIST and what they mean, and
-- it is identical at every site. This table says which of them actually
-- RETURNED DATA here, and how much - which no static file can know.
--
-- Join on `variable` to get both halves. A variable present in the dictionary
-- and absent here has zero rows at this site, and a variable present here and
-- absent from the dictionary is undeclared drift (see below).
--
-- Read this before modelling. A declared variable with a subject_count in the
-- single digits will not survive downstream feature guards
-- (minimum observation and binary-count thresholds), and knowing that here is
-- cheaper than discovering it in a skipped-feature report.
--
-- Undeclared variables: this table is built from pcx__client_timeline alone,
-- with no join to the registry, so a variable emitted by an upstream builder
-- that nobody declared in the dictionary CSV still appears. That is deliberate
-- - it is the drift detector. Reconciling the two is a set difference on
-- `variable`, not a lookup.
--
-- Dialect note: ARRAY_AGG / ARRAY_SORT / ARRAY_JOIN are Trino spellings and do
-- not execute on DuckDB. Verified by execution: array_join does not exist there,
-- and no portable spelling exists - Trino's LISTAGG requires WITHIN GROUP, which
-- DuckDB rejects, while DuckDB's LISTAGG(DISTINCT ...) is not valid Trino. The
-- parse-only DuckDB compatibility test does not catch this.
-- ============================================================================
CREATE TABLE pcx__client_dictionary_coverage AS

SELECT  timeline.variable,

        -- How much, and for how many people. The two are not redundant: a
        -- variable with many events over few subjects is a repeated
        -- measurement, not broad coverage.
        COUNT(*)                                    AS event_count,
        COUNT(DISTINCT timeline.subject_ref)        AS subject_count,

        -- When the variable starts and stops appearing. A max well before
        -- today usually means an upstream feed stopped rather than that the
        -- concept stopped occurring.
        MIN(timeline.event_date)                    AS event_date_min,
        MAX(timeline.event_date)                    AS event_date_max,

        -- A variable can populate more than one payload column, so every
        -- observed payload type is reported.
        NULLIF(
            TRIM(BOTH '|' FROM CONCAT(
                CASE WHEN COUNT(timeline.value_number)  > 0
                     THEN 'number|'  ELSE '' END,
                CASE WHEN COUNT(timeline.value_text)    > 0
                     THEN 'text|'    ELSE '' END,
                CASE WHEN COUNT(timeline.value_boolean) > 0
                     THEN 'boolean|' ELSE '' END)),
            '')                                     AS value_type,

        ARRAY_JOIN(
            ARRAY_SORT(ARRAY_AGG(DISTINCT timeline.source_type)),
            '|')                                    AS source_type,
        ARRAY_JOIN(
            ARRAY_SORT(ARRAY_AGG(DISTINCT timeline.assertion_level)),
            '|')                                    AS assertion_level,

        -- Observed enumeration, for low-cardinality text payloads only. This
        -- is the one column here that is genuinely unknowable in advance: for
        -- an LLM variable it reports the labels the extractor actually
        -- produced, which is how a drifting enum is caught. NONE_OF_THE_ABOVE
        -- is pinned last rather than sorted into the middle.
        CASE
            WHEN COUNT(DISTINCT timeline.value_text) BETWEEN 1 AND 20
            THEN CONCAT_WS('|',
                NULLIF(ARRAY_JOIN(
                    ARRAY_SORT(
                        ARRAY_AGG(DISTINCT timeline.value_text)
                            FILTER (WHERE timeline.value_text IS NOT NULL
                                    AND timeline.value_text
                                        <> 'NONE_OF_THE_ABOVE')),
                    '|'), ''),
                CASE WHEN BOOL_OR(
                        timeline.value_text = 'NONE_OF_THE_ABOVE')
                     THEN 'NONE_OF_THE_ABOVE' END)
        END                                         AS allowed_values

FROM    pcx__client_timeline AS timeline
GROUP BY
        timeline.variable
;
