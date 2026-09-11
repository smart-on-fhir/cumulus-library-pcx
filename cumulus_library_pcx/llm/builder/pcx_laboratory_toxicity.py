import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpLaboratoryToxicityBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Laboratory",
    task_tabular_display="laboratory",
    task_table_suffix="toxicity",
):
    """pcx__llm_laboratory_toxicity: one row per ToxicityMention
    in result.toxicities.

    toxicity_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "toxicity_index": "bigint",
            "toxicity": "varchar",
            "grade": "bigint",
            "grading_system": "varchar",
            "phase": "varchar",
            "event_date": "varchar",
            "event_date_precision": "varchar",
            "attribution": "varchar",
        })
