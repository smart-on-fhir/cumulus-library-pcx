from typing import Iterable

import cumulus_library
from cumulus_library.template_sql.base_templates import get_ctas_empty_query
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin
from cumulus_library_pcx.tools import filetool

class PcxNlpDiagnosisWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Diagnosis",
    task_tabular_display="diagnosis",
    task_table_suffix="wide",
):
    task_version = 2

    def _make_query_with_tables(self, tables: Iterable[str]):
        return cumulus_library.get_template(
            self.dest_table,
            filetool.path_llm_template(),
            table_names=sorted(tables),
            task_version=self.task_version,
        )

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        table_cols = [
            "note_ref",
            "encounter_ref",
            "subject_ref",
            "origin",
            "generated_on",
            "task_version",
            "system_fingerprint",
            "disease_subtype",
            "medulloblastoma_histology",
            "historical_diagnosis_term",
            "tumor_location_verbatim",
            "chang_m_stage",
            "age_at_diagnosis_months",
            "diagnosis_date",
            "diagnosis_date_precision",
            "diagnosis_date_gold",
            "diagnosis_date_gold_precision",
        ]
        # Match the populated SQL types; other columns are VARCHAR.
        return get_ctas_empty_query(
            schema_name=config.schema,
            table_name=self.dest_table,
            table_cols=table_cols,
            table_cols_types=[
                "bigint" if name in {"task_version", "age_at_diagnosis_months"}
                else "varchar"
                for name in table_cols
            ],
        )
