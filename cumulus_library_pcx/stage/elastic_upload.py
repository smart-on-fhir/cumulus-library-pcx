"""Elastic upload stage: upload the Elasticsearch export CSVs, then union them.

Export discovery, table names and SQL rendering live in tools.elastic_upload_tool.
This module owns the action order and the elastic_upload.toml manifest.
With no export the stage has no actions.
"""
from pathlib import Path

from cumulus_library_pcx.tools import elastic_upload_tool
from cumulus_library_pcx.tools.manifest import (
    Action, FileAction, SqlAction, save_actions_toml,
)

STAGE_TOML = 'elastic_upload.toml'


def make_stages() -> list[Action]:
    if not elastic_upload_tool.list_csv():
        return list()
    return [
        FileAction([elastic_upload_tool.path_upload_toml_manifest()], 'elastic_output CSV uploads'),
        SqlAction([elastic_upload_tool.make_union()], 'elastic_output union tasks'),
    ]


# Compatibility with stages/tools that use the established action-builder name.
make_actions = make_stages


def make() -> Path:
    return save_actions_toml(make_stages(), STAGE_TOML)


if __name__ == '__main__':
    print(make())
