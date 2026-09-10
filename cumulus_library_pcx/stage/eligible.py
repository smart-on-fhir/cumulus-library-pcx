"""
Eligibility stage: pcx__eligible_* tables.

    eligible_dx         time zero from tier 1 medulloblastoma casedef rows, age in months, ATRT and LLM diagnosis evidence
    eligible_surgery    definitive surgery day (LLM surgery_role, then structured tier 1 craniotomy) and age at surgery
    eligible_rx         methotrexate (causal contrast) and backbone chemo, ordered and administered, prior to t0
    eligible_radiation  radiation delivered, ordered or coded, prior to t0
    eligible            one row per subject with every ACNS0334 criterion as a nullable column (discovery cohort)
    eligible_trial      strict intersection of the structurally evaluable criteria (trial-like cohort)

Structured inputs: casedef, cohort_variable_union_rx, cohort_proc_craniotomy, cohort_proc_radiation,
cohort_dx_radiation, core__patient. LLM inputs: llm_diagnosis_wide, llm_surgery_wide,
llm_systemic_therapy_agent, llm_radiation_wide. The LLM wide tables are built first by this stage's
opening action (empty tables when no NLP output exists yet, see llm/builder).
"""
from pathlib import Path
from cumulus_library_pcx.tools import manifest, tablespace, filetool

# -----------------------------------------------------------------------------
# helper paths to "eligible" SQL files

def path_eligible(table_suffix: str | None) -> Path:
    """
    :param table_suffix: table name without prefix or "eligible"
    :return: Path to fully qualified table_name in athena dir
    """
    if table_suffix:
        eligible_table = tablespace.name_join('eligible', table_suffix)
    else:
        eligible_table = tablespace.name_prefix('eligible')
    return filetool.path_custom(f"{eligible_table}.sql")
# -----------------------------------------------------------------------------
# make targets, each renders template/<name>.sql -> athena/pcx__<name>.sql
# -----------------------------------------------------------------------------
def make_dx() -> list[Path]:
    return [path_eligible('dx')]

def make_treatment() -> list[Path]:
    return [path_eligible('surgery'),
            path_eligible('rx'),
            path_eligible('radiation')]

def make_eligible() -> list[Path]:
    return [path_eligible(None),
            path_eligible('trial')]

def make() -> list[Path]:
    actions = [
        manifest.SqlAction(make_dx(),
                           'eligible diagnosis: time zero, age in months, ATRT',
                           'build:serial'),
        manifest.SqlAction(make_treatment(),
                           'eligible treatment: definitive surgery, methotrexate and chemo, radiation',
                           'build:parallel'),
        manifest.SqlAction(make_eligible(),
                           'eligible criteria per subject, then trial-like intersection',
                           'build:serial'),
    ]
    return [manifest.save_actions_toml(actions, 'eligible.toml')]

if __name__ == '__main__':
    for target in make():
        print(target)
