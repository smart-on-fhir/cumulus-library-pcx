"""Kaplan-Meier count cubes based on the PCX-30 OS and EFS cubes, in months.

Builds pcx__kaplan_subject (one labeled row per eligible subject), the
pcx__kaplan_subject_demo cohort (not exported), then the cubes in
counts_kaplan.workflow (shared, exported).
"""
from cumulus_study_builder.tools import filetool, sql_stage, toml_tool
from cumulus_study_builder.tools.actions import SqlAction, FileAction, ExportAction

KAPLAN_SQL = 'pcx__kaplan_subject.sql'
DEMO_SQL = 'pcx__kaplan_subject_demo.sql'
WORKFLOW = 'counts_kaplan.workflow'

def make():
    sql = sql_stage.study_sql(KAPLAN_SQL)
    demo_sql = sql_stage.study_sql(DEMO_SQL)
    path = filetool.path_project(WORKFLOW)
    return toml_tool.save_actions_toml([
        SqlAction([sql], 'Kaplan-Meier count source'),
        SqlAction([demo_sql], 'Kaplan-Meier demo cohort'),
        FileAction([path], 'Kaplan-Meier counts', build_type='build:serial'),
        ExportAction(['pcx__cube_kaplan_os', 'pcx__cube_kaplan_efs'], 'Kaplan-Meier counts'),
        ExportAction(['pcx__meta_date', 'pcx__meta_version'], 'Study metadata', export_type='export:meta'),
    ], 'counts_kaplan.toml')
