from pathlib import Path
from cumulus_library_pcx.tools import manifest, tablespace, filetool, template

# -----------------------------------------------------------------------------
# helper paths to "eligible" athena files

def path_eligible(table_suffix: str | None) -> Path:
    """
    :param table_suffix: table name without prefix or "eligible"
    :return: Path to fully qualified table_name in athena dir
    """
    if table_suffix:
        eligible_table = tablespace.name_join('eligible', table_suffix)
    else:
        eligible_table = tablespace.name_prefix('eligible')
    return filetool.path_athena(f"{eligible_table}.sql")

# -----------------------------------------------------------------------------
# make targets

def make_dx() -> list[Path]:
    """
    :return: list Path to SQL file(s) with eligibility criteria for diagnosis
    """
    return [path_eligible('dx')]

def make_treatment() -> list[Path]:
    """
    :return: list Path to SQL file(s) with eligibility criteria for treatment
    """
    return [path_eligible('rx'),
            path_eligible('radiation'),
            path_eligible('surgery')]

def make_eligible() -> list[Path]:
    """
    :return: list Path to SQL file(s) with eligibility criteria *intersection*
    """
    return [path_eligible(None)]

def make() -> list[Path]:
    actions = [
        manifest.SqlAction(make_dx(),
                           'eligible criteria dx diagnosis',
                           'build:serial'),
        manifest.SqlAction(make_treatment(),
                           'eligible criteria rx medications',
                           'build:serial'),
        manifest.SqlAction(make_eligible(),
                           'eligible criteria intersection',
                           'build:serial'),
    ]

    return [manifest.save_actions_toml(actions, 'eligible.toml')]

if __name__ == '__main__':
    make()
