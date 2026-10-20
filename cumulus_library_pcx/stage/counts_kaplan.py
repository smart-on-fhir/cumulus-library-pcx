"""Kaplan-Meier count cubes in the PCX-30 OS and EFS cube layout.

Builds pcx__kaplan_subject (one labeled row per eligible subject),
then the cubes in counts_kaplan.workflow (shared, exported).
"""
from cumulus_study_builder.tools import filetool, sql_stage, toml_tool
from cumulus_study_builder.tools.actions import SqlAction, FileAction, ExportAction

KAPLAN_SQL = 'pcx__kaplan_subject.sql'
WORKFLOW = 'counts_kaplan.workflow'

def make():
    sql = sql_stage.study_sql(KAPLAN_SQL)
    path = filetool.path_project(WORKFLOW)
    return toml_tool.save_actions_toml([
        SqlAction([sql], 'Kaplan-Meier count source'),
        FileAction([path], 'Kaplan-Meier counts', build_type='build:serial'),
        ExportAction([path], 'Kaplan-Meier counts'),
    ], 'counts_kaplan.toml')