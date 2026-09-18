"""Sample stage: build the casedef note samples for chart review.

SQL rendering lives in tools.sample_tool. This module owns the action order,
the sample-size limits and the sample.toml manifest.
"""
from pathlib import Path

from cumulus_library_pcx.tools import sample_tool
from cumulus_library_pcx.tools.actions import Action, SqlAction, SqlParallelAction
from cumulus_library_pcx.tools.toml_tool import save_actions_toml

STAGE_TOML = 'sample.toml'
LIMIT_PATIENTS = 10
LIMIT_NOTES = 50


def make_actions() -> list[Action]:
    return [SqlAction(
                sample_tool.make_sample('sample_casedef'),
                'casedef FHIR DocumentReference + FHIR DiagnosticReport'),
            SqlAction(
                sample_tool.make_sample('sample_casedef_author'),
                'calc 1x for each note_ref the note_author_date'),
            SqlParallelAction(
                sample_tool.make_aspects(),
                f'sample for aspects {sample_tool.list_aspect_names()}'),
            SqlParallelAction(
                sample_tool.make_temporality_list(),
                f'sample temporality {sample_tool.TEMPORALITY}'),
            SqlParallelAction(
                sample_tool.make_temporality_limit_patient(LIMIT_PATIENTS),
                'sample size limit patients'),
            SqlParallelAction(
                sample_tool.make_temporality_limit_note(LIMIT_NOTES),
                'sample size limit notes')]

def make() -> Path:
    return save_actions_toml(make_actions(), STAGE_TOML)
