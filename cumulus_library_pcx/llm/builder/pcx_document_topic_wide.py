import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpDocumentTopicWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Document Topic",
    task_tabular_display="document_topic",
    task_table_suffix="wide",
):
    """pcx__llm_document_topic_wide: one row per note, flattening the scalar mention(s)
    response, diagnosis, molecular, event, metastasis, surgery, radiation,
    systemic_therapy, laboratory, predisposition, patient, registry_eligibility.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "response_relevance": "varchar",
            "response_confidence": "double",
            "response_reasoning": "varchar",
            "diagnosis_relevance": "varchar",
            "diagnosis_confidence": "double",
            "diagnosis_reasoning": "varchar",
            "molecular_relevance": "varchar",
            "molecular_confidence": "double",
            "molecular_reasoning": "varchar",
            "event_relevance": "varchar",
            "event_confidence": "double",
            "event_reasoning": "varchar",
            "metastasis_relevance": "varchar",
            "metastasis_confidence": "double",
            "metastasis_reasoning": "varchar",
            "surgery_relevance": "varchar",
            "surgery_confidence": "double",
            "surgery_reasoning": "varchar",
            "radiation_relevance": "varchar",
            "radiation_confidence": "double",
            "radiation_reasoning": "varchar",
            "systemic_therapy_relevance": "varchar",
            "systemic_therapy_confidence": "double",
            "systemic_therapy_reasoning": "varchar",
            "laboratory_relevance": "varchar",
            "laboratory_confidence": "double",
            "laboratory_reasoning": "varchar",
            "predisposition_relevance": "varchar",
            "predisposition_confidence": "double",
            "predisposition_reasoning": "varchar",
            "patient_relevance": "varchar",
            "patient_confidence": "double",
            "patient_reasoning": "varchar",
            "registry_eligibility_relevance": "varchar",
            "registry_eligibility_confidence": "double",
            "registry_eligibility_reasoning": "varchar",
        })
