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
    return [path_eligible('dx_date')]

def make_rx() -> list[Path]:
    """
    :return: list Path to SQL file(s) with eligibility criteria for medications
    """
    return [path_eligible(target) for target in
            ['rx_date',
             'rx_date_evidence',
             'rx_date_prior_class']]

def make_eligible() -> list[Path]:
    """
    :return: list Path to SQL file(s) with eligibility criteria *intersection*
    """
    return [path_eligible(None)]

# -----------------------------------------------------------------------------
def make_bins(sample_table_name:str|None) -> list[Path]:
    """
    :param sample_table_name: table to COPY via CTAS into three BINS
    :return: list Path to SQL file(s) with sample_table_name split into three BINS
    """
    if not sample_table_name:
        out = list()
        for gold in ['dx_date', 'rx_date']:
            for sample_table_name in [tablespace.name_join('eligible', f"{gold}_minus_gold")]:
                out.extend(make_bins(sample_table_name))
        return out
    else:
        sample_table_file = filetool.path_athena(f"{sample_table_name}.sql")
        sample_bin_file = filetool.path_athena(f"{sample_table_name}_bins.sql")

        filetool.write_text(
            template.load('sample_table_bins.sql', sample_table_name=sample_table_name),
            sample_bin_file)

        return [sample_table_file, sample_bin_file]

def make() -> list[Path]:
    actions = [
        manifest.SqlAction(make_dx(),
                           'eligible criteria dx diagnosis',
                           'build:serial'),
        manifest.SqlAction(make_rx(),
                           'eligible criteria rx medications',
                           'build:serial'),
        manifest.SqlAction(make_eligible(),
                           'eligible criteria intersection',
                           'build:serial'),
        manifest.SqlAction(make_bins(None),
                           'eligible criteria minus gold verification',
                           'build:serial')]

    return [manifest.save_actions_toml(actions, 'eligible.toml')]

if __name__ == '__main__':
    make()
