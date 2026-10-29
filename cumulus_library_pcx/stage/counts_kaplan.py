"""Kaplan-Meier count cubes based on the PCX-30 OS and EFS cubes, in months.

Builds pcx__kaplan_subject (one labeled row per eligible subject), the
pcx__kaplan_subject_strict cohort (not exported), then the cubes in
counts_kaplan.workflow (shared, exported): the OS and EFS Kaplan-Meier cubes over all
subjects and over the strict cohort, and cubes of pcx__eligible and pcx__outcome, the
tables that feed the Kaplan source.

The export also lists the default counts stage's cubes (counts.workflow, built there with
its floor of 10) and the meta tables, so one `export --stage counts_kaplan` zip holds every
cube. Exporting the counts stage alone gives a zip without the meta tables, which upload
rejects, and each export replaces the last one's files.
"""
import tomllib

from cumulus_study_builder.tools import filetool, sql_stage, toml_tool
from cumulus_study_builder.tools.actions import SqlAction, FileAction, ExportAction

KAPLAN_SQL = 'pcx__kaplan_subject.sql'
STRICT_SQL = 'pcx__kaplan_subject_strict.sql'
WORKFLOW = 'counts_kaplan.workflow'
COUNTS_WORKFLOW = 'counts.workflow'
KAPLAN_CUBES = ['pcx__cube_kaplan_os',
                'pcx__cube_kaplan_efs',
                'pcx__cube_kaplan_strict_os',
                'pcx__cube_kaplan_strict_efs']
SOURCE_CUBES = ['pcx__cube_eligible_casedef',
                'pcx__cube_eligible_prior_therapy',
                'pcx__cube_eligible_risk',
                'pcx__cube_eligible_exposure',
                'pcx__cube_outcome_os',
                'pcx__cube_outcome_efs',
                'pcx__cube_outcome_initial_therapy']

def counts_cubes() -> list[str]:
    """The table names the default counts stage builds from counts.workflow."""
    workflow = tomllib.loads(filetool.path_project(COUNTS_WORKFLOW).read_text())
    tables = list()
    for name in workflow['tables']:
        tables.append(f'pcx__{name}')
    return tables


def make():
    kaplan_sql = sql_stage.study_sql(KAPLAN_SQL)
    strict_sql = sql_stage.study_sql(STRICT_SQL)
    path = filetool.path_project(WORKFLOW)
    return toml_tool.save_actions_toml([
        SqlAction([kaplan_sql], 'Kaplan-Meier count source'),
        SqlAction([strict_sql], 'Kaplan-Meier strict cohort'),
        FileAction([path], 'Kaplan-Meier counts', build_type='build:serial'),
        ExportAction(KAPLAN_CUBES + SOURCE_CUBES, 'Kaplan-Meier counts'),
        ExportAction(counts_cubes(), 'Study counts, built by the counts stage'),
        ExportAction(['pcx__meta_date', 'pcx__meta_version'], 'Study metadata', export_type='export:meta'),
    ], 'counts_kaplan.toml')
