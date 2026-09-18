-- ==========================================================================
-- Grain: one row per subject_ref x variable x rx_class.
-- ==========================================================================
CREATE OR REPLACE VIEW pcx__client_timeline_latest AS
WITH

-- Events that can answer a "latest value" question. Filtering BEFORE
-- ranking means an unusable newer event never shadows a usable older one.
-- Missing interpretation/status is NOT unusable - it is reported as-is.
usable_events AS (
    SELECT  timeline.*
    FROM    pcx__client_timeline AS timeline
    -- some value payload is present
    WHERE   (
                timeline.value_text       IS NOT NULL
                OR timeline.value_number  IS NOT NULL
                OR timeline.value_boolean IS NOT NULL
            )
    -- explicit non-answers are excluded
    AND     (
                timeline.value_text IS NULL
                OR UPPER(timeline.value_text) NOT IN ('NONE_OF_THE_ABOVE', 'NOT_DOCUMENTED', 'UNAVAILABLE', 'UNKNOWN')
            )
    -- voided records are excluded
    AND     (
                timeline.status IS NULL
                OR LOWER(timeline.status) NOT IN ('entered-in-error', 'cancelled')
            )
),

-- Newest first. Ties: evidence date, then source_ref, then event_id -
-- fully deterministic.
ranked AS (
    SELECT  usable_events.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    usable_events.subject_ref,
                    usable_events.variable,
                    usable_events.rx_class
                ORDER BY
                    usable_events.event_date DESC NULLS LAST,
                    usable_events.evidence_date DESC NULLS LAST,
                    usable_events.source_ref ASC NULLS LAST,
                    usable_events.event_id ASC
            ) AS latest_rank
    FROM    usable_events
)

SELECT  ranked.*
FROM    ranked
WHERE   ranked.latest_rank = 1
;
