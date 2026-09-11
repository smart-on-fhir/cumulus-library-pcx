import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpSystemicTherapyAgentBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Systemic Therapy",
    task_tabular_display="systemic_therapy",
    task_table_suffix="agent",
):
    """pcx__llm_systemic_therapy_agent: one row per TherapyAgentMention
    in result.regimens.agents.

    regimen_index, agent_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "regimen_index": "bigint",
            "agent_index": "bigint",
            "delivery_status": "varchar",
            "agent_name": "varchar",
            "therapy_start_date": "varchar",
            "therapy_start_date_precision": "varchar",
            "therapy_stop_date": "varchar",
            "therapy_stop_date_precision": "varchar",
        })
