"""
Outcome stage: pcx__outcome_* tables, one row per subject in pcx__eligible.

    outcome_vital_status    deceased flag, death day, last-known-alive day (FHIR patient, encounters, LLM patient task)
    outcome_first_event     first EFS-type event: progression, recurrence, secondary malignancy, death
    outcome_exposure        methotrexate and radiation prior to first event, initial-therapy sequence, protocol names
    outcome                 overall survival (README section 3) and provisional event-free survival (section 5)

Depends on the eligible stage and on the LLM wide tables for patient, event, and
systemic-therapy regimens and anchors (built empty when NLP has not run).
"""
from pathlib import Path
from cumulus_library_pcx.tools import tablespace, filetool
from cumulus_library_pcx.tools.manifest import (
    Action,
    SqlAction,
    save_actions_toml
)

# -----------------------------------------------------------------------------
# helper path to custom "outcome" SQL files
# -----------------------------------------------------------------------------
def path_outcome(table_suffix: str | None) -> Path:
    """
    :param table_suffix: table name without prefix or "outcome"
    :return: Path to fully qualified table_name in custom dir
    """
    if table_suffix:
        outcome_table = tablespace.name_join('outcome', table_suffix)
    else:
        outcome_table = tablespace.name_prefix('outcome')
    return filetool.path_custom(f"{outcome_table}.sql")

# -----------------------------------------------------------------------------
# actions
# -----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    outcome_list = ['vital_status', 'first_event', 'exposure']
    return [SqlAction([path_outcome(t) for t in outcome_list],
                      'outcome vital status, then first event, then exposure prior to first event'),
            SqlAction([path_outcome(None)],
                      'outcome per subject: overall survival and provisional event-free survival')]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), 'outcome.toml')

if __name__ == '__main__':
    print(make)

