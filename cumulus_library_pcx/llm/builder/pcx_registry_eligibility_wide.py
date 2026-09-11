import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpRegistryEligibilityWideBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Registry Eligibility",
    task_tabular_display="registry_eligibility",
    task_table_suffix="wide",
):
    """pcx__llm_registry_eligibility_wide: one row per note, flattening the scalar mention(s)
    age_under_36_months_at_definitive_surgery, newly_diagnosed_embryonal_tumor,
    high_risk_disease, atrt_excluded, no_prior_chemotherapy, no_prior_radiation,
    adequate_renal_function, adequate_hepatic_function, adequate_cardiac_function,
    adequate_pulmonary_function, adequate_marrow_function.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "age_under_36_months_at_definitive_surgery_status": "varchar",
            "age_under_36_months_at_definitive_surgery_assessment_date": "varchar",
            "age_under_36_months_at_definitive_surgery_assessment_date_precision": "varchar",
            "newly_diagnosed_embryonal_tumor_status": "varchar",
            "newly_diagnosed_embryonal_tumor_assessment_date": "varchar",
            "newly_diagnosed_embryonal_tumor_assessment_date_precision": "varchar",
            "high_risk_disease_status": "varchar",
            "high_risk_disease_assessment_date": "varchar",
            "high_risk_disease_assessment_date_precision": "varchar",
            "atrt_excluded_status": "varchar",
            "atrt_excluded_assessment_date": "varchar",
            "atrt_excluded_assessment_date_precision": "varchar",
            "no_prior_chemotherapy_status": "varchar",
            "no_prior_chemotherapy_assessment_date": "varchar",
            "no_prior_chemotherapy_assessment_date_precision": "varchar",
            "no_prior_radiation_status": "varchar",
            "no_prior_radiation_assessment_date": "varchar",
            "no_prior_radiation_assessment_date_precision": "varchar",
            "adequate_renal_function_status": "varchar",
            "adequate_renal_function_assessment_date": "varchar",
            "adequate_renal_function_assessment_date_precision": "varchar",
            "adequate_hepatic_function_status": "varchar",
            "adequate_hepatic_function_assessment_date": "varchar",
            "adequate_hepatic_function_assessment_date_precision": "varchar",
            "adequate_cardiac_function_status": "varchar",
            "adequate_cardiac_function_assessment_date": "varchar",
            "adequate_cardiac_function_assessment_date_precision": "varchar",
            "adequate_pulmonary_function_status": "varchar",
            "adequate_pulmonary_function_assessment_date": "varchar",
            "adequate_pulmonary_function_assessment_date_precision": "varchar",
            "adequate_marrow_function_status": "varchar",
            "adequate_marrow_function_assessment_date": "varchar",
            "adequate_marrow_function_assessment_date_precision": "varchar",
        })
