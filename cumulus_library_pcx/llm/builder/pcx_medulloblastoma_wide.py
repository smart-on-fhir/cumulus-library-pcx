import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpMedulloblastomaWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Medulloblastoma",
    task_tabular_display="medulloblastoma",
    task_table_suffix="wide",
):
    """pcx__llm_medulloblastoma_wide: one row per note, flattening the scalar mention(s)
    molecular_group, methotrexate, radiation, survival.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "molecular_group_classification_method": "varchar",
            "molecular_group_source_report": "varchar",
            "molecular_group": "varchar",
            "methotrexate_status": "varchar",
            "methotrexate_first_received_date": "varchar",
            "methotrexate_assessed_through_date": "varchar",
            "radiation_status": "varchar",
            "radiation_first_received_date": "varchar",
            "radiation_assessed_through_date": "varchar",
            "patient_deceased": "boolean",
            "death_date": "varchar",
            "last_known_alive_date": "varchar",
        })
