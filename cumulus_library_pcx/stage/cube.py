"""Cube stage: build the count (cube) tables, then export them.

The table columns counted per source table live in tools.cube_tool.
This module owns the action order and the cube.toml manifest.
"""
from pathlib import Path

from cumulus_library_pcx.tools import cube_tool
from cumulus_library_pcx.tools.manifest import (
    Action, ExportAction, SqlAction, save_actions_toml,
)

STAGE_TOML = 'cube.toml'


def make_actions() -> list[Action]:
    population_sql_list = cube_tool.make_study_population()
    variable_sql_list = cube_tool.make_variable_union()
    casedef_sql_list = cube_tool.make_casedef()

    return [SqlAction(population_sql_list, 'SQL cube study population'),
            ExportAction(population_sql_list, 'export cube tables study populations'),

            SqlAction(variable_sql_list, 'SQL cube variable union'),
            ExportAction(variable_sql_list, 'export cube tables variable union'),

            SqlAction(casedef_sql_list, 'SQL cube casedef'),
            ExportAction(casedef_sql_list, 'export cube tables casedef')]

def make() -> Path:
    return save_actions_toml(make_actions(), STAGE_TOML)

if __name__ == '__main__':
    print(make())
