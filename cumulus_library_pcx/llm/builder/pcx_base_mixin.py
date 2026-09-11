from typing import Iterable

import cumulus_library
from cumulus_library import base_utils, databases
from cumulus_library.template_sql import sql_utils
from cumulus_library.template_sql.base_templates import get_ctas_empty_query

from cumulus_library_pcx.tools import filetool

# Source metadata columns every PCX wide table starts with, in projection order.
# Types match the populated SQL: generated_on is cast to VARCHAR, task_version to BIGINT.
SOURCE_COLS_TYPES = {
    "note_ref": "varchar",
    "encounter_ref": "varchar",
    "subject_ref": "varchar",
    "origin": "varchar",
    "generated_on": "varchar",
    "task_version": "bigint",
    "system_fingerprint": "varchar",
}


class PcxLLMBaseMixin:
    """Mixin providing shared flattening logic for PCX wide-table builders.

    Combine with cumulus_library.BaseTableBuilder to create a concrete builder:

        class MyBuilder(
            PcxLLMBaseMixin,
            cumulus_library.BaseTableBuilder,
            task_display="My Task",
            task_tabular_display="my_task",
            task_table_suffix="wide",
        ):
            def _make_empty_query(self, config):
                ...
    """

    def __init_subclass__(cls, task_display="", task_tabular_display="", task_table_suffix="", **kwargs):
        super().__init_subclass__(**kwargs)
        # Special variable for library builders
        cls.display_text = f"Transforming PCX {task_display} NLP..."

        # Other variables based on these keyword args
        # Progress text to display when checking possible source tables
        cls.progress_text = f"Discovering available NLP tables for PCX {task_display} variables..."

        # The common prefix across all source tables which vary by LLM deployment
        cls.src_table_prefix = f"pcx__nlp_{task_tabular_display.lower()}"

        # The ultimate destination table for the builder's resulting sql
        # This name should also match the relevant jinja template
        cls.dest_table = f"pcx__llm_{task_tabular_display.lower()}_{task_table_suffix.lower()}"

    @staticmethod
    def _is_table_valid(database: databases.DatabaseBackend, table_name: str) -> bool:
        """
        Check whether a source table has the expected result structure.
        The basic criterion is that the table has a structured 'result' column.
        This is a schema check, not a check for nonempty rows.
        Sub-classes can add more specific criteria by overriding this method.
        """
        return sql_utils.is_field_present(
            database=database,
            source_table=table_name,
            source_col="result",
            expected={},
        )

    def _make_query_with_tables(self, tables: Iterable[str]):
        """
        Create a query that uses the specified tables and the template defined by the path
        to the llm template directory and the stem of the destination table.
        """
        return cumulus_library.get_template(
            self.dest_table,
            filetool.path_llm_template(),
            table_names=sorted(tables),
        )

    def _get_valid_pcx_nlp_tables(self, database: databases.DatabaseBackend) -> set[str]:
        """
        Get a set of all valid PCX NLP tables from the database.
        Checks a list of known source tables for LLMs we support.

        NOTE: These models may need to be expanded depending on model availability.
        """
        source_tables = [
            f"{self.src_table_prefix}_claude_sonnet45",
            f"{self.src_table_prefix}_gpt51",
            f"{self.src_table_prefix}_gpt54",
            f"{self.src_table_prefix}_gpt_oss_120b",
        ]
        valid_tables = set()
        with base_utils.get_progress_bar() as progress:
            task = progress.add_task(
                self.progress_text,
                total=len(source_tables),
            )
            for source_table in source_tables:
                if self._is_table_valid(database, source_table):
                    valid_tables.add(source_table)
                progress.advance(task)
        return valid_tables

    def _make_empty_query(self, config: cumulus_library.StudyConfig):
        """Return an appropriate empty query for this task.

        Subclasses must implement this. Called when no valid source tables are
        found so the destination table is still created with the correct schema.
        """
        raise NotImplementedError(f"{type(self).__name__} must implement _make_empty_query")

    def _make_empty_query_from_types(
        self, config: cumulus_library.StudyConfig, value_cols_types: dict[str, str]
    ):
        """Empty destination table: the shared source columns followed by this task's value columns.

        value_cols_types maps column name -> SQL type, in the same order as the jinja template.
        """
        table_cols_types = SOURCE_COLS_TYPES | value_cols_types
        return get_ctas_empty_query(
            schema_name=config.schema,
            table_name=self.dest_table,
            table_cols=list(table_cols_types),
            table_cols_types=list(table_cols_types.values()),
        )

    def _make_query(self, config: cumulus_library.StudyConfig):
        valid_tables = self._get_valid_pcx_nlp_tables(config.db)
        if valid_tables:
            return self._make_query_with_tables(valid_tables)
        return self._make_empty_query(config)

    def prepare_queries(self, *args, config: cumulus_library.StudyConfig, **kwargs):
        self.queries.append(self._make_query(config=config))
