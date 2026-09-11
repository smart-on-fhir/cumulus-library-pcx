import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpSurgeryWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Surgery",
    task_tabular_display="surgery",
    task_table_suffix="wide",
):
    """pcx__llm_surgery_wide: one row per SurgeryMention
    in result.surgeries.

    surgery_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "surgery_index": "bigint",
            "surgery_role": "varchar",
            "age_at_surgery_months": "double",
            "residual_tumor_area_cm2": "double",
            "residual_measurement_verbatim": "varchar",
            "residual_assessment_date": "varchar",
            "residual_assessment_date_precision": "varchar",
            "surgery_type": "varchar",
            "extent_of_resection": "varchar",
            "surgery_date": "varchar",
            "surgery_date_precision": "varchar",
        })
