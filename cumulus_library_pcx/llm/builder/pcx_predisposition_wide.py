import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpPredispositionWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Predisposition",
    task_tabular_display="predisposition",
    task_table_suffix="wide",
):
    """pcx__llm_predisposition_wide: one row per CancerPredispositionMention
    in result.findings.

    finding_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "finding_index": "bigint",
            "gene_or_syndrome": "varchar",
            "status": "varchar",
            "variant_verbatim": "varchar",
            "report_date": "varchar",
            "report_date_precision": "varchar",
        })
