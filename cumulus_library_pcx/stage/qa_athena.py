"""QA stage: build the qa, warn and example tables, then their union counts.

File discovery, template rendering and union SQL live in tools.qa_athena_tool.
This module owns the action order and the qa_athena.toml manifest.
"""
from pathlib import Path

from cumulus_library_pcx.tools import qa_athena_tool
from cumulus_library_pcx.tools.manifest import (
    Action, SqlParallelAction, save_actions_toml,
)

STAGE_TOML = 'qa_athena.toml'


def make_actions() -> list[Action]:
    qa_athena_tool.copy_templates()
    return [
        SqlParallelAction(qa_athena_tool.list_qa(), 'all *qa* tables should have zero rows'),
        SqlParallelAction(qa_athena_tool.list_warn(), 'warn tables - nonzero rows are findings to eyeball, not failures'),
        SqlParallelAction(qa_athena_tool.list_example(), 'example tables for client users'),
        SqlParallelAction(qa_athena_tool.make_union(), 'union qa'),
    ]

def make() -> Path:
    return save_actions_toml(make_actions(), STAGE_TOML)

if __name__ == '__main__':
    print(make())
