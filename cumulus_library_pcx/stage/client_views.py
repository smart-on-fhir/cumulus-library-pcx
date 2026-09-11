"""
Client views stage: pcx__client_* tables, the flat contract exported as CSV.

    client_subject              one row per subject: time zero, age, ACNS0334 criteria, exposures, OS/EFS summary
    client_diagnosis            one row per subject: LLM diagnosis phenotype, baseline vs ever
    client_encounter            one row per subject x encounter: spine relative to t0 with coded-evidence flags
    client_exposure             one row per subject x exposure: METHOTREXATE / CHEMOTHERAPY / RADIATION timing
    client_timeline             one row per event: coded, LLM and derived evidence, 20-column contract shared with IBD
    client_timeline_latest      view: latest usable event per subject x variable x rx_class
    client_outcome              one row per subject x variable x date: OS, provisional EFS, death, first event
    client_dictionary_coverage  one row per timeline variable observed at this site

Same structure as cumulus-library-ibd-cds client_views.py with PCX variables: diagnosis replaces
paris, exposure replaces therapy_line. The SQL is study-specific and lives in custom/.
Depends on the eligible and outcome stages and on every LLM wide table in llm/athena.
"""
from pathlib import Path
from cumulus_library_pcx.tools import manifest, filetool, tablespace

VIEW_LIST = (
    "subject",
    "diagnosis",
    "encounter",
    "exposure",
    "timeline",
    "outcome",
    "dictionary_coverage",
)

# -----------------------------------------------------------------------------
# Views
# -----------------------------------------------------------------------------
def list_views() -> list[str]:
    """Return every flat view exported as CSV."""
    return [tablespace.name_join("client", suffix) for suffix in VIEW_LIST]

# -----------------------------------------------------------------------------
# helper paths to "client" SQL files
# -----------------------------------------------------------------------------
def path_client(table_suffix: str | None) -> Path:
    """
    :param table_suffix: table name without prefix or "client"
    :return: Path to fully qualified table_name in custom dir
    """
    if table_suffix:
        client_table = tablespace.name_join('client', table_suffix)
    else:
        client_table = tablespace.name_prefix('client')
    return filetool.path_custom(f"{client_table}.sql")

# -----------------------------------------------------------------------------
# make targets
# -----------------------------------------------------------------------------
def make_subject() -> list[Path]:
    return [path_client('subject')]

def make_diagnosis() -> list[Path]:
    return [path_client('diagnosis')]

def make_encounter() -> list[Path]:
    return [path_client('encounter')]

def make_exposure() -> list[Path]:
    return [path_client('exposure')]

def make_timeline() -> list[Path]:
    return [path_client('timeline'),
            path_client('timeline_latest')]

def make_outcome() -> list[Path]:
    return [path_client('outcome')]

def make_dictionary_coverage() -> list[Path]:
    return [path_client('dictionary_coverage')]


def make() -> list[Path]:
    actions = [manifest.FileAction([f'../spreadsheet/file_upload_client_views.toml'],
                                   'upload client_dictionary.csv'),
               manifest.SqlAction(make_subject(),
                                  'client subject',
                                  'build:serial'),
               manifest.SqlAction(make_diagnosis(),
                                  'client diagnosis',
                                  'build:serial'),
               manifest.SqlAction(make_encounter(),
                                  'client encounter',
                                  'build:serial'),
               manifest.SqlAction(make_exposure(),
                                  'client exposure',
                                  'build:serial'),
               manifest.SqlAction(make_timeline(),
                                  'client timeline',
                                  'build:serial'),
               manifest.SqlAction(make_outcome(),
                                  'client outcome',
                                  'build:serial'),
               manifest.SqlAction(make_dictionary_coverage(),
                                  'client dictionary coverage',
                                  'build:serial'),
               manifest.ExportAction(list_views(),
                                     "client SQL views -> CSV files",
                                     export_type="export:flat"),
               ]

    return [manifest.save_actions_toml(actions, 'client_views.toml')]

if __name__ == '__main__':
    for target in make():
        print(target)
