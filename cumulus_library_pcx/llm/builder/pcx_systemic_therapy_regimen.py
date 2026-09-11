import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpSystemicTherapyRegimenBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Systemic Therapy",
    task_tabular_display="systemic_therapy",
    task_table_suffix="regimen",
):
    """pcx__llm_systemic_therapy_regimen: one row per MedicalTherapyRegimenMention
    in result.regimens.

    regimen_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "regimen_index": "bigint",
            "phase": "varchar",
            "documented_trial_arm": "varchar",
            "protocol_name_verbatim": "varchar",
            "regimen_start_date": "varchar",
            "regimen_start_date_precision": "varchar",
            "regimen_stop_date": "varchar",
            "regimen_stop_date_precision": "varchar",
        })
