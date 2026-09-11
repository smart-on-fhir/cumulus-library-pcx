import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpLaboratoryResultBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Laboratory",
    task_tabular_display="laboratory",
    task_table_suffix="result",
):
    """pcx__llm_laboratory_result: one row per LaboratoryResultMention
    in result.results.

    result_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "result_index": "bigint",
            "test": "varchar",
            "result_verbatim": "varchar",
            "value": "double",
            "units": "varchar",
            "reference_range": "varchar",
            "collection_date": "varchar",
            "collection_date_precision": "varchar",
            "context": "varchar",
        })
