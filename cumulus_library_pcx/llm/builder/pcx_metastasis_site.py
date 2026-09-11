import cumulus_library
from cumulus_library_pcx.llm.builder.pcx_base_mixin import PcxLLMBaseMixin


class PcxNlpMetastasisSiteBuilder(
    PcxLLMBaseMixin,
    cumulus_library.BaseTableBuilder,
    task_display="Metastasis",
    task_tabular_display="metastasis",
    task_table_suffix="site",
):
    """pcx__llm_metastasis_site: one row per MetastasisSiteMention
    in result.metastasis_sites.

    metastasis_site_index: 1-based list position(s) from UNNEST WITH ORDINALITY,
    the join key back to the parent level. A note whose list is empty has no rows here.
    """

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        # Match the populated SQL types, in template column order.
        return self._make_empty_query_from_types(config, {
            "metastasis_site_index": "bigint",
            "site": "varchar",
            "site_date": "varchar",
            "site_date_precision": "varchar",
        })
