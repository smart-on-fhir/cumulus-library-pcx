import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpResponseWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Response",
    task_tabular_display="response",
    task_table_suffix="wide",
):
    """pcx__llm_response_wide: one row per ResponseAssessmentMention
    in result.assessments.

    assessment_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "assessment_index": "bigint",
            "timepoint": "varchar",
            "response": "varchar",
            "radiologically_evaluable": "boolean",
            "cytologically_evaluable": "boolean",
            "assessment_date": "varchar",
            "assessment_date_precision": "varchar",
            "assessment_method": "varchar",
            "review_context": "varchar",
        })
