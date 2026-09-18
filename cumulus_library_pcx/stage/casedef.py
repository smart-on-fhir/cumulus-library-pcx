"""Casedef stage: upload casedef.csv, then build the case cohort, aspects and timeline.

SQL rendering lives in tools.casedef_tool. This module owns the action order
and the casedef.toml manifest.
"""
from pathlib import Path

from cumulus_library_pcx.tools import casedef_tool
from cumulus_library_pcx.tools.staging import Action, FileAction, SqlAction
from cumulus_library_pcx.tools.toml_tool import save_actions_toml

STAGE_TOML = 'casedef.toml'


def make_actions() -> list[Action]:
    return [
        FileAction([casedef_tool.path_upload_toml()], 'case definition CSV upload'),
        SqlAction(casedef_tool.make_candidate(), 'filter include/exclude'),
        SqlAction(casedef_tool.make_casedef(), 'cohort from case definition (valueset_casedef)'),
        SqlAction(casedef_tool.make_aspects(), 'cohort for case definition aspects (dx, rx, lab, proc)'),
        SqlAction(casedef_tool.make_timeline(), 'timeline for casedef with variables'),
    ]

def make() -> Path:
    return save_actions_toml(make_actions(), STAGE_TOML)
