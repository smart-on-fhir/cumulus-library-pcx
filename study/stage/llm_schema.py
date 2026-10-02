"""Refresh schemas during local generation and Cumulus execution."""
from pathlib import Path
from cumulus_library import BaseTableBuilder
from cumulus_study_builder.config import set_study_root, discover_study_root
from cumulus_study_builder.stage import llm_schema

make = llm_schema.make

class SchemaBuilder(BaseTableBuilder):
    def prepare_queries(self, config, manifest, *args, **kwargs):
        set_study_root(discover_study_root(Path(__file__)))
        llm_schema.make_files()
