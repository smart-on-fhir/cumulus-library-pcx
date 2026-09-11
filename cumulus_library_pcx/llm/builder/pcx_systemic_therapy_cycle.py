import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpSystemicTherapyCycleBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Systemic Therapy",
    task_tabular_display="systemic_therapy",
    task_table_suffix="cycle",
):
    """pcx__llm_systemic_therapy_cycle: one row per MedicalTherapyCycleMention
    in result.cycles.

    cycle_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "cycle_index": "bigint",
            "phase": "varchar",
            "protocol_name_verbatim": "varchar",
            "completion_status": "varchar",
            "interruption_reason": "varchar",
            "cycle_name": "varchar",
            "cycle_start_date": "varchar",
            "cycle_start_date_precision": "varchar",
            "cycle_stop_date": "varchar",
            "cycle_stop_date_precision": "varchar",
        })
