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
# activity indexes

def make_activity_index() -> list[Path]:
    return [path_outcome('pucai_base'),
            path_outcome('pcdai_base')]

def make_remission_clinical() -> list[Path]:
    return [path_outcome('remission_clinical_evidence'),
            path_outcome('remission_clinical'),
            path_outcome('remission_clinical_sustained')]

# -----------------------------------------------------------------------------
# surgery (first qualifying surgery outcome)

def make_surgery() -> list[Path]:
    return [path_outcome('surgery')]

def make() -> list[Path]:
    actions = [manifest.FileAction([f'../spreadsheet/file_upload_outcome.toml'], 'PUCAI + PCDAI definitions'),
               manifest.SqlAction(make_activity_index(),
                                  'IBD outcome activity index (PUCAI + PCDAI)',
                                  'build:parallel'),
               manifest.SqlAction(make_remission_clinical(),
                                  'IBD outcome remission (remission_clinical)',
                                  'build:serial'),
               manifest.SqlAction(make_surgery(),
                                  'IBD outcome surgery (first qualifying surgery)',
                                  'build:parallel')]

    return [manifest.save_actions_toml(actions, 'outcome.toml')]

if __name__ == '__main__':
    make()
