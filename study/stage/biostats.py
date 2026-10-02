"""Study-owned biostats SQL order. Replace the demonstration with your protocol."""
from cumulus_study_builder.tools import sql_stage

def make():
    return sql_stage.make('biostats', ['biostats/analysis.sql'], exports=['analysis'])
