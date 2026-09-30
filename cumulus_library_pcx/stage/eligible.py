"""
Eligibility stage: pcx__eligible_* tables.

    eligible_dx         time zero from tier 1 medulloblastoma casedef rows, age in months, ATRT and LLM diagnosis evidence
    eligible_surgery    definitive surgery day (earliest LLM resection, then structured tier 1 craniotomy) and age at surgery
    eligible_rx         methotrexate (causal contrast) and backbone chemo, ordered and administered, prior to t0
    eligible_radiation  radiation delivered, ordered or coded, prior to t0
    eligible            one row per subject with every ACNS0334 criterion as a nullable column (discovery cohort)
    eligible_trial      strict intersection of the structurally evaluable criteria (trial-like cohort)

Structured inputs: casedef, cohort_variable_union_rx, cohort_proc_craniotomy, cohort_proc_radiation,
cohort_dx_radiation, core__patient. LLM inputs: llm_diagnosis_wide, llm_surgery_wide,
llm_systemic_therapy_agent, llm_radiation_wide. The LLM wide tables are built first by this stage's
llm_clinical_wide stage (rendered from sql/template, see tools/nlp_wide.py).
"""
from pathlib import Path
from cumulus_library_pcx.tools import tablespace, filetool
from cumulus_library_pcx.tools.actions import Action, SqlAction, SqlParallelAction
from cumulus_library_pcx.tools.toml_tool import save_actions_toml

# -----------------------------------------------------------------------------
# helper paths to custom "eligible"
# -----------------------------------------------------------------------------
def path_eligible(table_suffix: str | None) -> Path:
    eligible_table = tablespace.name_eligible(table_suffix)
    return filetool.path_sql_custom(f"{eligible_table}.sql")

# -----------------------------------------------------------------------------
# make targets
# -----------------------------------------------------------------------------
def list_dx() -> list[Path]:
    return [path_eligible('dx')]

def list_treatment() -> list[Path]:
    return [path_eligible('surgery'),
            path_eligible('rx'),
            path_eligible('radiation')]

def list_eligible() -> list[Path]:
    return [path_eligible(None),
            path_eligible('trial')]

#-----------------------------------------------------------------------------
# actions
#-----------------------------------------------------------------------------
def make_actions() -> list[Action]:
    return [SqlAction(
                list_dx(),
                'eligible diagnosis: time zero, age in months, ATRT'),
            SqlParallelAction(
                list_treatment(),
                'eligible treatment: definitive surgery, methotrexate and chemo, radiation'),
            SqlAction(
                list_eligible(),
                'eligible criteria per subject, then trial-like intersection')
    ]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make() -> Path:
    return save_actions_toml(make_actions(), 'eligible.toml')
