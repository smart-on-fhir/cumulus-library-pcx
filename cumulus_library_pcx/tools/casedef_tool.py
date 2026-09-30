"""Case definition: render the casedef cohort, aspect and timeline SQL.

The case definition is the valueset spreadsheet/casedef.csv (subtype, system,
code, display, tier). Its header row becomes the `casedef_columns` template
variable, so adding a column to casedef.csv carries it through every table.

This module renders SQL and names the upload. The stage (stage/casedef.py) owns
the action order, the labels and the casedef.toml manifest.

Build order, which the stage preserves:
    upload       valueset_casedef                      file_upload_casedef.toml
    candidate    cohort_casedef_candidate              casedef codes matched in the study population
    exclude      cohort_casedef_exclude                user-defined exclusions (empty by default)
    include      cohort_casedef_include                candidates whose subject is not excluded
    casedef      cohort_casedef                        case encounters with subject history and period
    aspects      cohort_casedef_dx, _lab, _proc, _rx   case encounters joined to each FHIR aspect
    timeline     cohort_timeline                       every study population encounter, flagged casedef / variable
"""
from pathlib import Path

from cumulus_library_pcx.tools import filetool, template
from cumulus_library_pcx.tools.settings import ENCOUNTER_REF

#-----------------------------------------------------------------------------
# Inputs
#-----------------------------------------------------------------------------
CASEDEF_CSV = 'casedef.csv'
UPLOAD_TOML = 'file_upload_casedef.toml'

CANDIDATE_STEPS = ['candidate', 'exclude', 'include']
ASPECTS = ['dx', 'lab', 'proc', 'rx']

#-----------------------------------------------------------------------------
# Names
#-----------------------------------------------------------------------------
def name_template(part: str | None = None) -> str:
    """
    name_template()      -> 'cohort_casedef.sql'
    name_template('dx')  -> 'cohort_casedef_dx.sql'
    """
    if part:
        return f'cohort_casedef_{part}.sql'
    return 'cohort_casedef.sql'

def path_upload_toml() -> str:
    """Upload workflow as the stage manifest references it (relative to cumulus_library_pcx/)."""
    return f'../spreadsheet/{UPLOAD_TOML}'

#-----------------------------------------------------------------------------
# Render
#-----------------------------------------------------------------------------
def template_kwargs(csv_file: Path | str = CASEDEF_CSV) -> dict:
    """Variables every casedef template receives: the casedef.csv header and the encounter reference column."""
    return {'casedef_columns': filetool.csv_columns(csv_file),
            'encounter_ref': ENCOUNTER_REF}

def save_template(sql_file: str, kwargs: dict | None = None) -> Path:
    if kwargs is None:
        kwargs = template_kwargs()
    return template.save(sql_file, **kwargs)

def save_template_list(sql_files: list[str]) -> list[Path]:
    """Render several templates, reading casedef.csv once."""
    kwargs = template_kwargs()
    out = list()
    for sql_file in sql_files:
        out.append(save_template(sql_file, kwargs))
    return out

#-----------------------------------------------------------------------------
# Make: one function per build step, each returns the custom SQL it wrote
#-----------------------------------------------------------------------------
def make_candidate() -> list[Path]:
    """candidate, then exclude, then include: the order the SQL depends on."""
    return save_template_list([name_template(step) for step in CANDIDATE_STEPS])

def make_casedef() -> list[Path]:
    return save_template_list([name_template()])

def make_aspects() -> list[Path]:
    return save_template_list([name_template(aspect) for aspect in ASPECTS])

def make_timeline() -> list[Path]:
    return save_template_list(['cohort_timeline.sql'])
