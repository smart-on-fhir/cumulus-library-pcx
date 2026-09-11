import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpSystemicTherapyAdministrationBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Systemic Therapy",
    task_tabular_display="systemic_therapy",
    task_table_suffix="administration",
):
    """pcx__llm_systemic_therapy_administration: one row per TherapyAdministrationMention
    in result.regimens.agents.administrations.

    regimen_index, agent_index, administration_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "regimen_index": "bigint",
            "agent_index": "bigint",
            "administration_index": "bigint",
            "delivery_status": "varchar",
            "phase": "varchar",
            "cycle_name": "varchar",
            "administration_date": "varchar",
            "administration_date_precision": "varchar",
            "dose_amount": "double",
            "dose_unit": "varchar",
            "route": "varchar",
            "high_dose_methotrexate_explicit_bool": "boolean",
        })
