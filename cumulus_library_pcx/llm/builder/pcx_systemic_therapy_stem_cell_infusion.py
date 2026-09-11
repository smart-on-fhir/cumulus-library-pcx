import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpSystemicTherapyStemCellInfusionBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Systemic Therapy",
    task_tabular_display="systemic_therapy",
    task_table_suffix="stem_cell_infusion",
):
    """pcx__llm_systemic_therapy_stem_cell_infusion: one row per StemCellInfusionMention
    in result.stem_cell_infusions.

    stem_cell_infusion_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "stem_cell_infusion_index": "bigint",
            "delivery_status": "varchar",
            "phase": "varchar",
            "infusion_date": "varchar",
            "infusion_date_precision": "varchar",
            "cycle_name": "varchar",
            "cell_source": "varchar",
            "cd34_cells_per_kg": "double",
        })
