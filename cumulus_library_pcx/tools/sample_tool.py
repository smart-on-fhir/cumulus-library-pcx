"""Note samples: render the sample_casedef SQL for chart review.

Samples are FHIR DocumentReference + DiagnosticReport notes of casedef subjects,
cut three ways:
    sample_casedef, sample_casedef_author   every casedef note, and its author date (once per note_ref)
    sample_casedef_<aspect>                 notes whose encounter matches 1+ study variable of that aspect
    sample_casedef_<temporality>            notes relative to the 1st coded casedef match
    sample_casedef_<temporality>_limit_*    the same, capped at N patients or N notes

This module renders SQL. The stage (stage/sample.py) owns the action order,
the labels, the sample-size limits and the sample.toml manifest.
"""
from pathlib import Path

from cumulus_library_pcx.tools import filetool, template, tablespace
from cumulus_library_pcx.tools.fhir_reference import Aspect
from cumulus_library_pcx.tools.settings import ENCOUNTER_REF
from cumulus_library_pcx.tools.variable_tool import list_aspect_names

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
# Step 1: sample_casedef
#-----------------------------------------------------------------------------
def make_sample(table_name: str | None = None) -> list[Path]:
    if not table_name:
        table_name = 'sample_casedef'
    return [template.save(f'{table_name}.sql', encounter_ref=ENCOUNTER_REF)]

#-----------------------------------------------------------------------------
# Step 2: for each Aspect
#-----------------------------------------------------------------------------
def make_supported_aspects() -> list[Path]:
    out = list()
    for aspect in list_aspect_names():
        out.append(make_aspect(aspect))
    return out

def make_aspect(aspect: Aspect | str) -> Path:
    """
    Intended use:
    * Aspect.dx:    sample casedef notes that have an encounter matching 1+ "dx" study variable(s)
                    Validate if case definition was "first" diagnosis.
    * Aspect.rx:    sample casedef notes that have an encounter matching 1+ "rx" study variable(s)
                    Validate medications were active/stopped/etc
    * Aspect.lab:   sample casedef notes that have an encounter matching 1+ "lab" study variable(s)
                    Validate lab values

    :param aspect: name of aspect to sample
    :return: path to Athena SQL
    """
    if isinstance(aspect, Aspect):
        aspect = aspect.name
    content = template.load('sample_casedef_aspect', aspect=aspect, encounter_ref=ENCOUNTER_REF)
    table = tablespace.name_prefix(f'sample_casedef_{aspect}')
    return filetool.save_sql_generated(filetool.path_sql_generated(f'{table}.sql'), content)

#-----------------------------------------------------------------------------
# Step 4: with sample size limits
#-----------------------------------------------------------------------------
def make_temporality_limit_patient(limit: int = 10) -> list[Path]:
    return make_temporality_list('sample_casedef_temporality_limit_patient', limit)

def make_temporality_limit_note(limit: int = 50) -> list[Path]:
    return make_temporality_list('sample_casedef_temporality_limit_note', limit)

#-----------------------------------------------------------------------------
# Temporality helpers
#-----------------------------------------------------------------------------
def make_temporality_list(template_name: str='sample_casedef_temporality', limit: int | None = None) -> list[Path]:
    """One SQL file per TEMPORALITY, in TEMPORALITY order."""
    out = list()
    for temporality in TEMPORALITY:
        out.append(make_temporality(template_name, temporality, limit))
    return out

def make_temporality(template_name: str, temporality: str, limit: int | None = None) -> Path:
    """
    make_temporality('sample_casedef_temporality_limit_note', 'pre', 50)
        -> custom/pcx__sample_casedef_pre_limit_note_50.sql

    :param template_name: name of the SQL template to load
    :param temporality: one of TEMPORALITY
    :param limit: patients or notes in sample
    :return: path to Athena SQL
    """
    table_name = template_name.replace('temporality', temporality)
    if limit:
        limit = str(limit)
        table_name = f'{table_name}_{limit}'
    else:
        limit = ''
    text = template.load(template_name,
                         encounter_ref=ENCOUNTER_REF,
                         temporality=temporality,
                         limit=limit)
    target_table = tablespace.name_prefix(table_name)
    return Path(filetool.write_text(text, filetool.path_sql_generated(f'{target_table}.sql')))
