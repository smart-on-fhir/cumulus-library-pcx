import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpMolecularReportBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Molecular",
    task_tabular_display="molecular",
    task_table_suffix="report",
):
    """pcx__llm_molecular_report: one row per MolecularReportMention
    in result.reports.

    report_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    methods is the comma-joined MolecularMethod list.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "report_index": "bigint",
            "molecular_group": "varchar",
            "methods": "varchar",
            "report_date": "varchar",
            "report_date_precision": "varchar",
        })
