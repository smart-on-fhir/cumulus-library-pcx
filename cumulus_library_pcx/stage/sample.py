from pathlib import Path
from cumulus_library_pcx.tools.settings import ENCOUNTER_REF
from cumulus_library_pcx.tools import filetool, template, tablespace
from cumulus_library_pcx.stage.study_variable import Aspect, list_aspect_names
from cumulus_library_pcx.tools.manifest import (
    Action,
    SqlAction,
    SqlParallelAction,
    save_actions_toml
)

#-----------------------------------------------------------------------------
# Sample encounters relative to "1st coded casedef match"
#
# pre = before
# peri = during
# peri_post = during or after
# post = after
#-----------------------------------------------------------------------------
TEMPORALITY = ['pre', 'peri', 'peri_post', 'post']

#-----------------------------------------------------------------------------
# Template Step 1: sample_casedef
#-----------------------------------------------------------------------------
def make_template_sample(table_name: str | None) -> list[Path]:
    if not table_name:
        table_name = 'sample_casedef'
    return [template.copy(f"{table_name}.sql", encounter_ref=ENCOUNTER_REF)]

#-----------------------------------------------------------------------------
# Template Step 2: for each Aspect
#-----------------------------------------------------------------------------
def make_template_aspect() -> list[Path]:
    return [_make_template_aspect(aspect) for aspect in list_aspect_names()]

def _make_template_aspect(aspect: Aspect | str) -> Path:
    """
    Intended use:
    * Aspect.dx:    sample casedef notes that have an encounter matching 1+ "dx" study variable(s)
                    Validate if case definition was "first" kidney transplant.
    * Aspect.rx:    sample casedef notes that have an encounter matching 1+ "rx" study variable(s)
                    Validate medications were active/stopped/etc
    * Aspect.lab:   sample casedef notes that have an encounter matching 1+ "lab" study variable(s)
                    Validate lab values

    :param aspect: name of aspect to sample
    :return: path to Athena SQL
    """
    if isinstance(aspect, Aspect):
        return _make_template_aspect(aspect.name)
    content = template.load('sample_casedef_aspect.sql', aspect=aspect, encounter_ref=ENCOUNTER_REF)
    table = tablespace.name_prefix(f'sample_casedef_{aspect}')
    path = filetool.path_athena(f'{table}.sql')
    return filetool.save_athena(path, content)

#-----------------------------------------------------------------------------
# Template Step 3: for each TEMPORALITY
#-----------------------------------------------------------------------------
def make_template_temporality() -> list[Path]:
    template_name = 'sample_casedef_temporality'
    return [_make_template_temporality(template_name, temporality) for temporality in TEMPORALITY]

#-----------------------------------------------------------------------------
# Template Step 4: with sample size limits
#-----------------------------------------------------------------------------
def make_template_temporality_limit_patient(limit: int = 10) -> list[Path]:
    template_name = 'sample_casedef_temporality_limit_patient'
    return [_make_template_temporality(template_name, temporality, limit) for temporality in TEMPORALITY]

def make_template_temporality_limit_note(limit: int = 50) -> list[Path]:
    template_name = 'sample_casedef_temporality_limit_note'
    return [_make_template_temporality(template_name, temporality, limit) for temporality in TEMPORALITY]

def _make_template_temporality(template_name:str, temporality:str, limit: int = None) -> Path:
    """
    :param template_name: name of the SQL template to load
    :param temporality: str one of ['pre', 'peri', 'peri_post', 'post']
    :param limit: int patients or notes in sample
    :return: path to Athena SQL
    """
    table_name = template_name.replace('temporality', temporality)

    if limit:
        limit = str(limit)
        table_name = f'{table_name}_{limit}'
    else:
        limit = ''
    text = template.load(f'{template_name}.sql',
                         encounter_ref=ENCOUNTER_REF,
                         temporality=temporality,
                         limit=limit)
    target_table = tablespace.name_prefix(table_name)
    target_file = filetool.path_athena(f'{target_table}.sql')
    return Path(filetool.write_text(text, target_file))

#-----------------------------------------------------------------------------
# Actions
#-----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    return [SqlAction(
                make_template_sample('sample_casedef'),
                'casedef FHIR DocumentReference + FHIR DiagnosticReport'),
            SqlAction(
                make_template_sample('sample_casedef_author'),
                'calc 1x for each note_ref the note_author_date'),
            SqlParallelAction(
                make_template_aspect(),
                f'sample for aspects {list_aspect_names()}'),
            SqlParallelAction(
                make_template_temporality(),
                f'sample temporality {TEMPORALITY}'),
            SqlParallelAction(
                make_template_temporality_limit_patient(10),
                'sample size limit patients'),
            SqlParallelAction(
                make_template_temporality_limit_note(50),
                'sample size limit notes'),
    ]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), 'sample.toml')

if __name__ == '__main__':
    print(make)
