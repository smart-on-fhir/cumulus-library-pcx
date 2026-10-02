"""Cumulus Library runs this for the llm_schema stage: it refreshes the study's schemas."""
from cumulus_library import BaseTableBuilder
from cumulus_study_builder.stage import llm_schema

make = llm_schema.make

class SchemaBuilder(BaseTableBuilder):
    def prepare_queries(self, config, manifest, *args, **kwargs):
        llm_schema.runtime(__file__)
