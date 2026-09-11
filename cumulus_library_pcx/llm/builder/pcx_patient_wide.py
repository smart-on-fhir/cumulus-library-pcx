import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpPatientWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Patient Timeline",
    task_tabular_display="patient",
    task_table_suffix="wide",
):
    """pcx__llm_patient_wide: one row per note, flattening the scalar mention(s)
    vital_status.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "vital_status": "varchar",
            "death_date": "varchar",
            "death_date_precision": "varchar",
            "last_known_alive_date": "varchar",
            "last_known_alive_date_precision": "varchar",
        })
