from pathlib import Path
from cumulus_library_pcx.tools import settings, tablespace, toml_tool, template
from cumulus_library_pcx.tools.actions import Action, SqlAction, ExportAction

TEMPLATE_LIST = ['meta_data', 'meta_version']

def list_tables() -> list[str]:
    return tablespace.name_prefix(TEMPLATE_LIST)

def make_study_meta_sql(data_package_version:int = settings.DATA_PACKAGE_VERSION) -> list[Path]:
    """
    https://docs.smarthealthit.org/cumulus/library/creating-studies.html#metadata-tables
    """
    return [template.copy(t, data_package_version=str(data_package_version)) for t in TEMPLATE_LIST]

def make_actions() -> list[Action]:
    """
    Make SQL study metadata and export metadata actions.
    """
    file_list = make_study_meta_sql()

    return [SqlAction(file_list, 'SQL study metadata'),
            ExportAction(file_list, 'export study metadata', 'export:meta'),
    ]

def make() -> list[Path]:
    return [toml_tool.save_actions_toml(make_actions(), 'study_meta.toml')]
