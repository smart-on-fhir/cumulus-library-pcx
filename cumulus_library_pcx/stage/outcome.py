from pathlib import Path
from cumulus_library_pcx.tools import manifest, tablespace, filetool

# -----------------------------------------------------------------------------
# helper paths to "outcome" athena files

def path_outcome(table_suffix: str | None) -> Path:
    """
    :param table_suffix: table name without prefix or "outcome"
    :return: Path to fully qualified table_name in athena dir
    """
    if table_suffix:
        outcome_table = tablespace.name_join('outcome', table_suffix)
    else:
        outcome_table = tablespace.name_prefix('outcome')
    return filetool.path_athena(f"{outcome_table}.sql")

# -----------------------------------------------------------------------------
# surgery (first qualifying surgery outcome)

def make_outcomes() -> list[Path]:
    return [path_outcome('death'),
            path_outcome('event_type_placeholder'),
            path_outcome('event_type_placeholder')]

def make() -> list[Path]:
    actions = [manifest.SqlAction(make_outcomes(),
                                  'outcome_death (deceased)',
                                  'build:parallel')]

    return [manifest.save_actions_toml(actions, 'outcome.toml')]

if __name__ == '__main__':
    make()
