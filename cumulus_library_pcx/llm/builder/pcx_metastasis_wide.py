import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpMetastasisWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Metastasis",
    task_tabular_display="metastasis",
    task_table_suffix="wide",
):
    """pcx__llm_metastasis_wide: one row per note, flattening the scalar mention(s)
    staging_inputs.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "csf_collection_site": "varchar",
            "csf_collection_date": "varchar",
            "csf_collection_date_precision": "varchar",
            "brain_mri_date": "varchar",
            "brain_mri_date_precision": "varchar",
            "spine_mri_date": "varchar",
            "spine_mri_date_precision": "varchar",
            "spine_mri_findings": "varchar",
            "brain_mri_findings": "varchar",
            "csf_cytology": "varchar",
            "extraneural_metastasis": "varchar",
        })
