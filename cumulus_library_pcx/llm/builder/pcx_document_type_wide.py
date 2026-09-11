import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpDocumentTypeWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Document Type",
    task_tabular_display="document_type",
    task_table_suffix="wide",
):
    """pcx__llm_document_type_wide: one row per note, flattening the scalar mention(s)
    document_type.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "document_type": "varchar",
            "confidence": "double",
        })
