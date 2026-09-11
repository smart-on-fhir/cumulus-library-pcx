import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpPatientAnchorBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Patient Timeline",
    task_tabular_display="patient",
    task_table_suffix="anchor",
):
    """pcx__llm_patient_anchor: one row per TimelineAnchorMention
    in result.anchors.

    anchor_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "anchor_index": "bigint",
            "anchor": "varchar",
            "anchor_date": "varchar",
            "anchor_date_precision": "varchar",
            "protocol_name": "varchar",
        })
