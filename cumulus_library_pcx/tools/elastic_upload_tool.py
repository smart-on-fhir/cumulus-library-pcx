"""Elastic upload: name the Elasticsearch export CSVs and render their union SQL.

The export is optional. Its CSVs (one per query topic) are written by the
elastic_query stage to $ELASTIC_OUTPUT_DIR, or $CUMULUS_LIBRARY_DATA_PATH/elastic/output.
Each CSV uploads as table pcx__elastic_<file simplename>, and pcx__elastic_union
stacks them with a `topic` column.

This module finds the export, names its tables and renders SQL. The stage
(stage/elastic_upload.py) owns the action order and the elastic_upload.toml manifest.
With no export, the stage has no actions.
"""
import os
from pathlib import Path

from cumulus_library_pcx.tools import filetool, toml_tool, settings, tablespace, template
from cumulus_library_pcx.tools.fhir_reference import Aspect
from cumulus_library_pcx.tools.actions import UploadWorkflow
from cumulus_library_pcx.tools.settings import ENCOUNTER_REF

#-----------------------------------------------------------------------------
# Inputs
#-----------------------------------------------------------------------------
UPLOAD_TOML = 'file_upload_elastic.toml'
UPLOAD_PREFIX = 'elastic_'

#-----------------------------------------------------------------------------
# Paths
#-----------------------------------------------------------------------------
def path_output() -> Path | None:
    """
    :return: $ELASTIC_OUTPUT_DIR if set, else $CUMULUS_LIBRARY_DATA_PATH/elastic/output, else None
    """
    if settings.ELASTIC_OUTPUT_DIR:
        return Path(settings.ELASTIC_OUTPUT_DIR)
    if settings.CUMULUS_LIBRARY_DATA_PATH:
        return Path(settings.CUMULUS_LIBRARY_DATA_PATH) / 'elastic' / 'output'
    print('skipping optional elastic_upload stage, ELASTIC_OUTPUT_DIR not set')
    return None

def path_upload_toml() -> Path:
    """Upload workflow, written beside the export CSVs. Call only when list_csv() is not empty."""
    return path_output() / UPLOAD_TOML

def path_upload_toml_manifest() -> str:
    """Upload workflow as the stage manifest references it (relative to cumulus_library_pcx/)."""
    return os.path.relpath(path_upload_toml(), start=filetool.path_project())

#-----------------------------------------------------------------------------
# Export CSVs and their tables
#-----------------------------------------------------------------------------
def list_csv() -> list[Path]:
    """Export CSVs, or an empty list when there is no export."""
    output_path = path_output()
    if output_path and output_path.exists():
        return list(output_path.glob('*.csv'))
    return list()

def table_for_file(filename: Path | str) -> str:
    """'medulloblastoma.csv' -> 'pcx__elastic_medulloblastoma'"""
    return tablespace.name_elastic(filetool.file_to_simplename(filename))

def list_tables(files: list[Path] | None = None) -> list[str]:
    if files is None:
        files = list_csv()
    return [table_for_file(file) for file in files]

#-----------------------------------------------------------------------------
# SQL
#-----------------------------------------------------------------------------
def select_union(table_list: list[str]) -> str:
    """One SELECT per table, labelled with its topic, joined by UNION ALL."""
    sql = list()
    for table in table_list:
        topic = tablespace.name_trim(table)
        sql.append(f"\tSELECT '{topic}'\t AS topic, * FROM {table}")
    return ' UNION ALL\n'.join(sql)

#-----------------------------------------------------------------------------
# Make: each returns the file it wrote
#-----------------------------------------------------------------------------
def make_union(aspect: Aspect | None = None) -> Path:
    """
    make_union()           -> custom/pcx__elastic_union.sql       (template elastic_union.sql)
    make_union(Aspect.dx)  -> custom/pcx__elastic_union_dx.sql    (template elastic_union_dx.sql)
    """
    cohort = f'union_{aspect.name}' if aspect else 'union'
    return filetool.save_sql_generated(tablespace.name_elastic(cohort),
                                       template.load(f'elastic_{cohort}',
                                              encounter_ref=ENCOUNTER_REF,
                                              select_union=select_union(list_tables())))

def make_upload_toml() -> Path:
    """Write the upload workflow for the export CSVs beside them."""
    return toml_tool.save_upload_toml(workflow=UploadWorkflow(file_list=list_csv(),
                                                              prefix=UPLOAD_PREFIX),
                                      toml_file=path_upload_toml())
