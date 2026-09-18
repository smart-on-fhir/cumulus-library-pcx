from pathlib import Path
from cumulus_library_pcx.tools import variable_tool
from cumulus_library_pcx.tools.manifest import (
    Action,
    SqlAction,
    save_actions_toml
)
#-----------------------------------------------------------------------------
# Actions
#-----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    """
    Make cohort UNION variables as one big table
    Make cohort WIDE variables as one big table (tabular with each column is a variable)
    :return: list of TOML outputs
    """
    aspect_list = variable_tool.list_aspect_names()

    return [SqlAction(
                variable_tool.make_union_bool(),
                'variable union (bool)'),
            SqlAction(
                variable_tool.make_union_aspect(),
                f'variable union {aspect_list}'),
            SqlAction([
                variable_tool.make_wide_bool()],
                'variable wide (bool)'),
            SqlAction(
                variable_tool.make_wide(),
                f'variable wide {aspect_list}'),
    ]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), 'study_variable_wide.toml')

if __name__ == '__main__':
    print(make)
