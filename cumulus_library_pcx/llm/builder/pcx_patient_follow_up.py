import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpPatientFollowUpBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Patient Timeline",
    task_tabular_display="patient",
    task_table_suffix="follow_up",
):
    """pcx__llm_patient_follow_up: one row per EventFreeFollowUpMention
    in result.event_free_follow_up.

    follow_up_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "follow_up_index": "bigint",
            "event_free": "boolean",
            "assessment_date": "varchar",
            "assessment_date_precision": "varchar",
            "assessment_method": "varchar",
        })
