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
from cumulus_library_pcx.tools import filetool, tablespace
from cumulus_library_pcx.tools.actions import Action, SqlAction, FileAction, ExportAction
from cumulus_library_pcx.tools.toml_tool import save_actions_toml

# -----------------------------------------------------------------------------
# Client tables data dictionary
# -----------------------------------------------------------------------------
UPLOAD_TOML = 'file_upload_client_views.toml'

# -----------------------------------------------------------------------------
# Views
# -----------------------------------------------------------------------------
VIEW_LIST = (
    "subject",
    "diagnosis",
    "encounter",
    "exposure",
    "timeline",
    "outcome",
    "dictionary_coverage",
)

def list_views() -> list[str]:
    """Return every flat view exported as CSV."""
    return [tablespace.name_join("client", suffix) for suffix in VIEW_LIST]

# -----------------------------------------------------------------------------
# Client namespace and path
# -----------------------------------------------------------------------------
def name_view(table_suffix: str | None) -> str:
    """
    :param table_suffix: table name without prefix or "client"
    :return: $prefix_client_tablename
    """
    if table_suffix:
        return tablespace.name_join('client', table_suffix)
    else:
        return tablespace.name_prefix('client')

def path_client(table_suffix: str | None) -> Path:
    client_table = name_view(table_suffix)
    return filetool.path_custom(f"{client_table}.sql")

# -----------------------------------------------------------------------------
# actions
# -----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    return [FileAction([f'../spreadsheet/{UPLOAD_TOML}'],
                       'upload client_dictionary.csv'),
            SqlAction([path_client('subject')],
                      'client subject'),
            SqlAction([path_client('diagnosis')],
                      'client diagnosis'),
            SqlAction([path_client('encounter')],
                      'client encounter'),
            SqlAction([path_client('exposure')],
                      'client exposure'),
            SqlAction([path_client('timeline'), path_client('timeline_latest')],
                      'client timeline'),
            SqlAction([path_client('outcome')],
                      'client outcome'),
            SqlAction([path_client('dictionary_coverage')],
                      'client dictionary coverage'),
            ExportAction(list_views(),
                         "client SQL views -> CSV files",
                         export_type="export:flat")
    ]
# -----------------------------------------------------------------------------
# make
# -----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), 'client_views.toml')

if __name__ == '__main__':
    print(make())
