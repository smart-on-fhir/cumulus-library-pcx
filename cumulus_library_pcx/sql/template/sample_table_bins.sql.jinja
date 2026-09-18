-- ============================================================================
-- Round-robin note bins for sample table.
--
-- Template params (study convention):
--   {{ sample_table_name }}  (e.g. prefix__eligible_dx_date_minus_gold)
--
-- Produces:
--   {{ sample_table_name }}_group_map  - one row per group_name with its note count and assigned bin
--   {{ sample_table_name }}_bin1/2/3  - the rows evenly split by bin
--
-- Bin count is EXPLICITLY 3 for now, on purpose - largest groups are dealt round-robin (MOD 3).
-- ============================================================================

-- =========================================================
-- 1. Largest groups are distributed across 3 bins.
-- =========================================================

CREATE TABLE {{ sample_table_name }}_group_map AS

WITH group_size AS (
    SELECT
        group_name,
        COUNT(DISTINCT note_ref) AS cnt_note
    FROM {{ sample_table_name }}
    GROUP BY group_name
),

ranked AS (
    SELECT
        group_name,
        cnt_note,
        ROW_NUMBER() OVER (
            ORDER BY cnt_note DESC, group_name
        ) AS rn
    FROM group_size
)

SELECT
    group_name,
    cnt_note,
    MOD(rn - 1, 3) + 1 AS group_bin
FROM ranked
;

-- =========================================================
-- CTAS Bins
-- =========================================================

CREATE TABLE {{ sample_table_name }}_bin1 AS

SELECT  sample.*
FROM    {{ sample_table_name }} AS sample
JOIN    {{ sample_table_name }}_group_map AS group_map
ON      sample.group_name = group_map.group_name
WHERE   group_map.group_bin = 1
;

CREATE TABLE {{ sample_table_name }}_bin2 AS

SELECT  sample.*
FROM    {{ sample_table_name }} AS sample
JOIN    {{ sample_table_name }}_group_map AS group_map
ON      sample.group_name = group_map.group_name
WHERE   group_map.group_bin = 2
;

CREATE TABLE {{ sample_table_name }}_bin3 AS

SELECT  sample.*
FROM    {{ sample_table_name }} AS sample
JOIN    {{ sample_table_name }}_group_map AS group_map
ON      sample.group_name = group_map.group_name
WHERE   group_map.group_bin = 3
;

-- =========================================================
-- Verify BIN(s) are roughly even
-- =========================================================

SELECT
    group_map.group_bin,
    COUNT(DISTINCT sample.subject_ref) AS cnt_pat,
    COUNT(DISTINCT sample.note_ref) AS cnt_note,
    COUNT(DISTINCT sample.group_name) AS cnt_group
FROM {{ sample_table_name }} AS sample
JOIN {{ sample_table_name }}_group_map AS group_map
    ON sample.group_name = group_map.group_name
GROUP BY group_map.group_bin
ORDER BY group_map.group_bin
;
