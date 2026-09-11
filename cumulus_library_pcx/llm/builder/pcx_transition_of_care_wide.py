import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpTransitionOfCareWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Transition of Care",
    task_tabular_display="transition_of_care",
    task_table_suffix="wide",
):
    """pcx__llm_transition_of_care_wide: one row per note, flattening the scalar mention(s)
    transfer_in, diagnosis_setting, definitive_surgery_setting, prior_therapy_at_entry.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "transfer_in_timing": "varchar",
            "transfer_in_date": "varchar",
            "transfer_in_date_precision": "varchar",
            "transfer_in_reason": "varchar",
            "diagnosis_setting": "varchar",
            "imaging_detected_externally": "boolean",
            "surgery_setting": "varchar",
            "prior_therapy_exposure": "varchar",
            "prior_therapy_modalities": "varchar",
        })
