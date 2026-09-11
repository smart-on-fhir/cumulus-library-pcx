import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpRadiationWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Radiation",
    task_tabular_display="radiation",
    task_table_suffix="wide",
):
    """pcx__llm_radiation_wide: one row per RadiationRoundMention
    in result.radiation_rounds.

    radiation_round_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "radiation_round_index": "bigint",
            "delivery_status": "varchar",
            "phase": "varchar",
            "indication": "varchar",
            "assessed_through_date": "varchar",
            "assessed_through_date_precision": "varchar",
            "dose_verbatim": "varchar",
            "radiation_method": "varchar",
            "radiation_field": "varchar",
            "radiation_start_date": "varchar",
            "radiation_start_date_precision": "varchar",
            "radiation_end_date": "varchar",
            "radiation_end_date_precision": "varchar",
            "focal_dose_to_primary_site": "double",
            "total_dose_to_primary_site": "double",
            "focal_dose_to_metastatic_site": "double",
            "total_dose_to_metastatic_site": "double",
            "craniospinal_dose": "double",
            "whole_ventricular_dose": "double",
            "dose_units": "varchar",
        })
