import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpEventWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Event",
    task_tabular_display="event",
    task_table_suffix="wide",
):
    """pcx__llm_event_wide: one row per EventMention
    in result.events.

    event_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "event_index": "bigint",
            "event_type": "varchar",
            "source_of_event_diagnosis": "varchar",
            "event_date": "varchar",
            "event_date_precision": "varchar",
            "date_of_progression_mri": "varchar",
            "date_of_progression_mri_precision": "varchar",
            "confirmation_date": "varchar",
            "confirmation_date_precision": "varchar",
        })
