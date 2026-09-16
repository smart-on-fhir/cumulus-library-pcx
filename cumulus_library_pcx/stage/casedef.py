from pathlib import Path
from cumulus_library_pcx.tools.settings import ENCOUNTER_REF
from cumulus_library_pcx.tools import tablespace, filetool, template
from cumulus_library_pcx.tools.manifest import (
    Action,
    FileAction,
    SqlAction,
    save_actions_toml
)

#-----------------------------------------------------------------------------
# Upload casedef.csv file(s)
# Common: users add custom spreadsheet/casedef*.csv files
# Rare: change the UPLOAD_FILE path; file contents are generated
#-----------------------------------------------------------------------------
UPLOAD_FILE = 'file_upload_casedef.toml'

#-----------------------------------------------------------------------------
# Template Helpers
#-----------------------------------------------------------------------------
def make_template(table_suffix: str | None) -> Path:
    if table_suffix:
        table_name = f'cohort_casedef_{table_suffix}'
    else:
        table_name = 'cohort_casedef'
    return copy_template(f'{table_name}.sql')

def casedef_columns() -> list[str]:
    """
    :return: ['subtype','system','code','display','tier']
    """
    return filetool.csv_columns('casedef.csv')

def copy_template(template_sql:str) -> Path:
    return template.copy(template_sql,
                         casedef_columns=casedef_columns(),
                         encounter_ref=ENCOUNTER_REF)
#-----------------------------------------------------------------------------
# Template
#-----------------------------------------------------------------------------
def make_template_candidate() -> list[Path]:
    return [make_template(c)
            for c in ['candidate', 'exclude', 'include']]

def make_template_casedef() -> list[Path]:
    return [copy_template('cohort_casedef.sql')]

def make_template_aspects() -> list[Path]:
    return [make_template(a)
            for a in ['dx', 'lab', 'proc', 'rx']]

def make_template_timeline() -> list[Path]:
    return [copy_template('cohort_timeline.sql')]

#-----------------------------------------------------------------------------
# Actions
#-----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    return [FileAction(['../spreadsheet/file_upload_casedef.toml'],
                       'case definition CSV upload'),
            SqlAction(make_template_candidate(),
                      'filter include/exclude'),
            SqlAction(make_template_casedef(),
                      'cohort from case definition (valueset_casedef)'),
            SqlAction(make_template_aspects(),
                      'cohort for case definition aspects (dx, rx, lab, proc)'),
            SqlAction(make_template_timeline(),
                      'timeline for casedef with variables'),
    ]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> list[Path]:
    return [save_actions_toml(make_actions(), 'casedef.toml')]

if __name__ == '__main__':
    for target in make():
        print(target)
