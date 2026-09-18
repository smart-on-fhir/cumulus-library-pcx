#!/usr/bin/env python3
"""Generate a synthetic, real-world-like PCX cohort and export the eligible and outcome tables.

    make-pcx test-synthetic [--patients 1000] [--seed 334] [--noise 1.0] [--no-utilization-screen]
        regenerates tests/data/synthetic: the derived tables, synthetic__truth.csv and the upstream tables
    python tests/synthetic.py OUTPUT_DIR [same options] [--include-inputs]
        the same generator aimed at any directory

This file lives with the tests, not in the study package: cumulus_library_pcx/ is for real data.
`make-pcx test-synthetic` loads it from the repository checkout (an editable install from a clone).

The CSV files in OUTPUT_DIR are what `SELECT * FROM pcx__<table>` would download from Athena
for every table built by the eligible and outcome stages (eligible.toml, outcome.toml):

    pcx__eligible_dx, pcx__eligible_surgery, pcx__eligible_rx, pcx__eligible_radiation,
    pcx__eligible, pcx__eligible_trial,
    pcx__outcome_vital_status, pcx__outcome_first_event, pcx__outcome_exposure, pcx__outcome

How it works
    1. Simulate each patient's latent truth: tumor, molecular group, age, stage, surgery,
       chemotherapy with or without methotrexate, radiation, relapse, death, follow-up.
    2. Emit the UPSTREAM tables the stages read (tests/data/schema.sql): casedef, encounters,
       orders, procedures and the LLM wide tables, with EHR-like gaps and disagreements.
    3. Run the study's real custom/pcx__*.sql in DuckDB, in the order the stage tomls list them.
    4. Export every derived table in Athena's CSV download format.
   Because step 3 is the real SQL, the derived tables can never drift from the study logic.

Population: children diagnosed at 3 years old or younger (under 48 months) with a CNS embryonal
tumor, calibrated to ACNS0334 (PMC12833527, https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/).
    Table 1     sex, age (median 1.97 y), M-stage, extent of resection, histology, tumor mix
    Treatment   induction x3 (vincristine, cyclophosphamide, etoposide, cisplatin, with or without
                high-dose methotrexate), consolidation x3 (carboplatin, thiotepa)
    Outcome     Group 3 5-year EFS 33% without vs 70% with methotrexate, SHH about 100%,
                ETMR and pineoblastoma poor with no methotrexate benefit, relapses within
                about 19 months, 4% toxic death, most survivors never irradiated
Unlike the trial, methotrexate is NOT randomized: it is confounded by indication (metastatic
disease, anaplasia, treatment era, very young age), so a naive comparison is biased and an
adjusted one should recover the planted effect. synthetic__truth.csv holds the latent truth
per subject so an analysis can be scored against it.

Real-world features kept on purpose
    - subjects 36 to 47 months old, who fail the under-36-months criterion
    - ATRT (exclusion), ETMR, pineoblastoma and other embryonal tumors (no tier 1 t0 today)
    - transfers who had surgery and chemotherapy elsewhere before their first encounter here
    - the study_population utilization screen (2+ encounters spanning 365+ days, visits at
      ages 0 to 8), which silently removes early deaths, see limitations.md
    - follow-up that ends at loss to follow-up, the 9th birthday, or the data extract day

Options
    --patients N    rows in pcx__eligible. Patients screened out upstream (failed utilization,
                    ATRT-only case definition, no core__patient row) are simulated, counted in
                    the report, and replaced until N is reached.
    --noise X       scales every gap and disagreement in GAP below. 0 is perfectly documented,
                    1 is the default. What remains at 0 is structural (transfers, salvage
                    radiation after a "no radiation" note, tier 2 codes before tier 1).
    --no-utilization-screen
                    keep the early deaths, as if workplan 2.7 were done. 5-year EFS then sits
                    close to the paper instead of about 10 points above it.
    --include-inputs
                    also keep the upstream tables in OUTPUT_DIR as plain CSV, in the
                    tests/data/warn fixture style, loadable with tests/sqltest.py connect(data_dir).
                    Always on for `make-pcx test-synthetic`.
    --seed S        same seed, same files. Patient N has the same latent truth at any --noise.

Requires duckdb and numpy (pip install -e ".[test]") and the repository checkout.

Contains no real patients and must never be used for clinical decision-making.
"""
import argparse
import csv
import math
import tempfile
import tomllib
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path

import duckdb
import numpy as np

from cumulus_library_pcx.tools import filetool

###############################################################################
# Study constants
###############################################################################
STAGES = ['eligible.toml', 'outcome.toml']
TRUTH_FILENAME = 'synthetic__truth.csv'

EXTRACT_DAY = date(2026, 6, 30)             # last day any EHR evidence can carry
STUDY_PERIOD_START = date(2008, 1, 1)       # spreadsheet/include_study_period.csv
UTILIZATION_ENC_MIN = 2                     # spreadsheet/include_utilization.csv
UTILIZATION_DAYS_MIN = 365
VISIT_AGE_YEARS_MAX = 9                     # study_population keeps visits at ages 0-8
AGE_MONTHS_MAX = 48                         # "3 years old or younger" at presentation
DAYS_PER_MONTH = 30.4375

INCLUDE_STUDY_PERIOD = [{'period_start': '2008-01-01', 'period_end': None, 'include_history': True}]
INCLUDE_UTILIZATION = [{'enc_min': UTILIZATION_ENC_MIN, 'enc_max': 100000,
                        'days_min': UTILIZATION_DAYS_MIN, 'days_max': 365000}]

###############################################################################
# Population, calibrated to ACNS0334 Table 1 unless noted
###############################################################################
# Trial: 46 medulloblastoma, 14 ETMR, 9 pineoblastoma, 8 other. ATRT went to ACNS0333, but
# in an EHR the ATRT children are in the same clinic, so they are here as the exclusion.
TUMOR_MIX = {'MB': 0.55, 'ETMR': 0.11, 'PINEO': 0.08, 'OTHER': 0.11, 'ATRT': 0.15}

# Trial medulloblastoma (n=46): Group 3 25, SHH 11, Group 4 2, the rest unclassified. WNT is rare in
# infants. SHH is kept near 11 of 46 so the all-medulloblastoma EFS lands near the paper's 46% vs 68%.
MB_GROUP_MIX = {'G3': 0.64, 'SHH': 0.25, 'G4': 0.08, 'WNT': 0.03}

M_STAGES = ['M0', 'M1', 'M2', 'M3']
EXTENTS = ['GROSS_TOTAL_RESECTION', 'NEAR_TOTAL_RESECTION', 'PARTIAL_RESECTION', 'BIOPSY']
HISTOLOGIES = ['CLASSIC', 'DESMOPLASTIC_NODULAR', 'EXTENSIVE_NODULARITY_MBEN', 'LARGE_CELL_ANAPLASTIC']


@dataclass
class Kind:
    """Parameters for one tumor kind (medulloblastoma molecular group, or a non-MB tumor)."""
    age_beta: tuple             # age under 36 months = 36 * Beta(a, b)
    p_age_36_to_47: float       # share presenting at 3 years old (trial-ineligible by age)
    p_male: float
    m_stage: list               # M0, M1, M2, M3. Trial overall: 0.44, 0.04, 0.16, 0.36
    extent: list                # GTR, NTR, STR, biopsy. Trial overall: 0.51, 0.16, 0.34, 0
    histology: list             # classic, desmoplastic, MBEN, large cell anaplastic (MB only)
    efs_without_mtx: float      # cured share without methotrexate. Toxic death and second malignancy
                                # take about 3 points off, and the untreated are less often metastatic
    mtx_log_odds: float         # planted methotrexate effect on the log-odds of cure
    relapse_median_months: float
    p_death_after_relapse: float


KIND = {
    #  Group 3: EFS 33% vs 70%, OS 40% vs 80% (P = 0.037). This is THE planted effect.
    'G3': Kind(age_beta=(2.4, 1.2), p_age_36_to_47=0.22, p_male=0.53,
               m_stage=[0.35, 0.05, 0.17, 0.43], extent=[0.52, 0.16, 0.32, 0.00],
               histology=[0.66, 0.02, 0.00, 0.32],
               efs_without_mtx=0.34, mtx_log_odds=1.60, relapse_median_months=8.0, p_death_after_relapse=0.86),
    #  SHH: 11 of 11 disease-free at 5 years in either arm, 6 of 11 metastatic, 8 of 11 with residual.
    'SHH': Kind(age_beta=(1.8, 1.8), p_age_36_to_47=0.08, p_male=0.50,
                m_stage=[0.48, 0.03, 0.17, 0.32], extent=[0.45, 0.20, 0.35, 0.00],
                histology=[0.22, 0.55, 0.18, 0.05],
                efs_without_mtx=0.97, mtx_log_odds=0.40, relapse_median_months=10.0, p_death_after_relapse=0.35),
    #  Group 4: 2 patients, both metastatic, 1 long-term survivor.
    'G4': Kind(age_beta=(2.6, 1.1), p_age_36_to_47=0.40, p_male=0.60,
               m_stage=[0.35, 0.05, 0.15, 0.45], extent=[0.55, 0.15, 0.30, 0.00],
               histology=[0.88, 0.02, 0.00, 0.10],
               efs_without_mtx=0.45, mtx_log_odds=0.60, relapse_median_months=12.0, p_death_after_relapse=0.65),
    #  WNT: not seen in the trial, rare under 4 years old, excellent prognosis.
    'WNT': Kind(age_beta=(2.8, 1.0), p_age_36_to_47=0.50, p_male=0.45,
                m_stage=[0.85, 0.03, 0.05, 0.07], extent=[0.70, 0.15, 0.15, 0.00],
                histology=[0.95, 0.00, 0.00, 0.05],
                efs_without_mtx=0.92, mtx_log_odds=0.00, relapse_median_months=14.0, p_death_after_relapse=0.40),
    #  ETMR: EFS 33% vs 20% (no benefit), 79% localized, every relapse inside 1 year.
    'ETMR': Kind(age_beta=(2.2, 1.5), p_age_36_to_47=0.12, p_male=0.45,
                 m_stage=[0.79, 0.00, 0.14, 0.07], extent=[0.45, 0.17, 0.38, 0.00],
                 histology=None,
                 efs_without_mtx=0.30, mtx_log_odds=0.00, relapse_median_months=5.0, p_death_after_relapse=0.90),
    #  Pineoblastoma: EFS 0% vs 17% (no benefit), a third localized, 1 survivor of 9.
    'PINEO': Kind(age_beta=(2.0, 1.6), p_age_36_to_47=0.15, p_male=0.50,
                  m_stage=[0.33, 0.08, 0.15, 0.44], extent=[0.22, 0.10, 0.33, 0.35],
                  histology=None,
                  efs_without_mtx=0.10, mtx_log_odds=0.00, relapse_median_months=7.0, p_death_after_relapse=0.92),
    #  Embryonal tumor NOS and the rest of the non-MB stratum (non-MB EFS 40% vs 31%).
    'OTHER': Kind(age_beta=(2.2, 1.4), p_age_36_to_47=0.15, p_male=0.50,
                  m_stage=[0.60, 0.04, 0.14, 0.22], extent=[0.50, 0.15, 0.30, 0.05],
                  histology=None,
                  efs_without_mtx=0.45, mtx_log_odds=0.00, relapse_median_months=8.0, p_death_after_relapse=0.80),
    #  ATRT is not in the paper (sent to ACNS0333): methotrexate is standard, about a third cured.
    'ATRT': Kind(age_beta=(1.5, 2.0), p_age_36_to_47=0.10, p_male=0.52,
                 m_stage=[0.62, 0.05, 0.13, 0.20], extent=[0.40, 0.20, 0.35, 0.05],
                 histology=None,
                 efs_without_mtx=0.30, mtx_log_odds=0.60, relapse_median_months=6.0, p_death_after_relapse=0.90),
}

# Prognostic shifts on the log-odds of cure. M-stage and anaplasia are centered on their
# prevalence inside each kind so Kind.efs_without_mtx stays the marginal value.
LOG_ODDS_METASTATIC = -0.70
LOG_ODDS_ANAPLASTIC = -0.50
LOG_ODDS_RESIDUAL = -0.30               # partial resection or biopsy, centered on 0.35
LOG_ODDS_UPFRONT_RADIATION = 0.80       # older children given craniospinal RT first
LOG_ODDS_RECENT_ERA = 0.15              # supportive care, diagnosed 2016 or later

P_TOXIC_DEATH = 0.04                    # 3 of 77 died on therapy
P_LATE_RELAPSE = 0.03                   # the paper saw none beyond 19 months, an EHR will
RELAPSE_MONTHS_MAX = 22.0
DEATH_AFTER_RELAPSE_MEDIAN_DAYS = 180
P_SECOND_MALIGNANCY = 0.02              # among long-term survivors, doubled after radiation
LOSS_TO_FOLLOWUP_PER_YEAR = 0.06

# Methotrexate by indication (log-odds). Sicker children get it more often, so the naive
# contrast UNDERSTATES the benefit.
MTX_LOG_ODDS = {'intercept': -0.90, 'metastatic': 0.90, 'anaplastic': 0.50,
                'recent_era': 0.80, 'under_8_months': -1.20, 'atrt': 1.60}

P_TRANSFER = 0.07                       # surgery and chemotherapy started elsewhere
P_TRANSFER_PRIOR_RADIATION = 0.25
P_RADIATION_FIRST_36_TO_47 = 0.25       # 3 year olds given craniospinal RT before chemotherapy
P_RADIATION_AFTER_CHEMO = {'under_36': 0.10, '36_to_47': 0.45}
P_SALVAGE_RADIATION = 0.55
P_SECOND_LOOK_SURGERY = 0.08
P_TREATED_PER_PROTOCOL = 0.75
P_BIOPSY_BEFORE_RESECTION = 0.10
P_NOT_RECEIVED_NOTE_BEFORE_RADIATION = 0.35
P_PRIOR_HISTORY_HERE = 0.30             # born or followed here before the tumor

INDUCTION = ['vincristine', 'cyclophosphamide', 'etoposide', 'cisplatin']
CONSOLIDATION = ['carboplatin', 'thiotepa']
MAINTENANCE = ['vincristine', 'cisplatin', 'cyclophosphamide']      # after upfront craniospinal RT
METHOTREXATE = 'methotrexate'

# How notes spell the agents: usual name, a variant, an abbreviation (noise). eligible_rx counts every
# ADMINISTERED agent as chemotherapy and finds methotrexate by '%methotrexate%' or '%mtx%'.
AGENT_SPELLING = {
    'vincristine': ['vincristine', 'Vincristine', 'VCR'],
    'cyclophosphamide': ['cyclophosphamide', 'Cytoxan', 'CPM'],
    'etoposide': ['etoposide', 'VP-16', 'VP16'],
    'cisplatin': ['cisplatin', 'Cisplatin', 'CDDP'],
    'carboplatin': ['carboplatin', 'Carboplatin', 'carbo'],
    'thiotepa': ['thiotepa', 'Thiotepa', 'TT'],
    'methotrexate': ['methotrexate', 'high-dose methotrexate', 'HD-MTX'],
}

PROTOCOL_WITH_MTX = ['ACNS0334', 'Head Start III', 'SJYC07']
PROTOCOL_WITHOUT_MTX = ['ACNS0334', 'CCG-99703', 'Head Start II']
PROTOCOL_ATRT = ['ACNS0333']
PROTOCOL_RADIATION_FIRST = ['ACNS0332', 'SJMB03']
PROTOCOL_SPELLING = ['{}', 'COG {}', 'as per {}', '{} (off study)']

CASEDEF_SUBTYPE = {'MB': 'medulloblastoma', 'ETMR': 'etmr', 'PINEO': 'pineoblastoma',
                   'OTHER': 'cns_embryonal', 'ATRT': 'atrt'}
LLM_SUBTYPE = {'MB': 'MEDULLOBLASTOMA', 'ETMR': 'ETMR', 'PINEO': 'PINEOBLASTOMA',
               'OTHER': 'OTHER_CNS_EMBRYONAL', 'ATRT': 'ATRT'}
NONE_OF_THE_ABOVE = 'NONE_OF_THE_ABOVE'

###############################################################################
# Noise: EHR gaps and disagreements at --noise 1.0 (each probability scales with --noise)
###############################################################################
GAP = {
    'core_patient_row_missing': 0.01,
    'birthdate_missing': 0.01,
    'gender_missing': 0.01,
    'casedef_tier2_only': 0.06,             # never coded with a specific tier 1 diagnosis
    'casedef_tier1_late': 0.05,             # first tier 1 code 3+ months after presentation
    'study_period_end_missing': 0.002,
    'llm_diagnosis_missing': 0.12,          # no diagnosis note retrieved for the subject
    'llm_subtype_not_stated': 0.04,
    'llm_subtype_wrong': 0.01,              # a note calls a medulloblastoma ATRT, or the reverse
    'llm_histology_not_stated': 0.25,
    'llm_m_stage_not_stated': 0.30,
    'llm_age_not_stated': 0.40,
    'llm_age_wrong': 0.03,
    'llm_date_month_precision': 0.03,
    'llm_date_year_precision': 0.005,
    'llm_date_missing': 0.05,
    'llm_date_after_note': 0.002,
    'llm_surgery_missing': 0.10,
    'llm_extent_not_stated': 0.12,
    'llm_surgery_date_wrong': 0.03,
    'proc_craniotomy_missing': 0.15,
    'proc_craniotomy_undated': 0.01,
    'rx_orders_missing': 0.10,
    'rx_methotrexate_order_never_given': 0.03,
    'llm_agents_missing': 0.15,
    'llm_agent_abbreviated': 0.004,         # VCR, CDDP: not matched by the agent patterns
    'llm_leucovorin_named': 0.10,           # rescue drug extracted as if it were chemotherapy
    'llm_protocol_not_stated': 0.35,
    'radiation_structured_missing': 0.30,   # irradiated at an outside proton center
    'llm_radiation_missing': 0.10,
    'llm_radiation_not_received_not_stated': 0.15,
    'fhir_deceased_flag_missing': 0.15,
    'fhir_death_date_missing': 0.10,
    'fhir_death_date_wrong': 0.05,
    'llm_death_missing': 0.30,
    'llm_death_date_wrong': 0.15,
    'encounter_after_death': 0.03,
    'llm_event_missing': 0.12,
    'llm_event_undated': 0.05,
    'llm_event_two_types_same_day': 0.04,
}


class Noise:
    def __init__(self, rng: np.random.Generator, scale: float):
        self.rng = rng
        self.scale = scale

    def hit(self, gap: str) -> bool:
        """
        :return: True when this gap or disagreement happens
        """
        return self.rng.random() < min(GAP[gap] * self.scale, 0.95)


###############################################################################
# Small helpers
###############################################################################
def pick(rng, options: list, weights: list):
    weights = np.asarray(weights, dtype=float)
    return options[int(rng.choice(len(options), p=weights / weights.sum()))]


def pick_key(rng, mix: dict) -> str:
    return pick(rng, list(mix.keys()), list(mix.values()))


def sigmoid(value: float) -> float:
    return 1.0 / (1.0 + math.exp(-value))


def logit(value: float) -> float:
    return math.log(value / (1.0 - value))


def days(count) -> timedelta:
    return timedelta(days=int(count))


def uniform_days(rng, low: int, high: int) -> timedelta:
    """
    :return: whole days in [low, high]
    """
    return days(rng.integers(low, high + 1))


def lognormal_days(rng, median_days: float, sigma: float, low: int, high: int) -> timedelta:
    return days(np.clip(rng.lognormal(math.log(median_days), sigma), low, high))


def completed_months(start: date, end: date) -> int:
    """
    Same as Athena DATE_DIFF('month', start, end).
    """
    months = (end.year - start.year) * 12 + (end.month - start.month)
    if end.day < start.day:
        months -= 1
    return months


def add_years(day: date, years: int) -> date:
    if day.month == 2 and day.day == 29:
        day = day.replace(day=28)
    return day.replace(year=day.year + years)


###############################################################################
# Latent truth
###############################################################################
@dataclass
class Patient:
    index: int
    subject_ref: str = None
    tumor: str = None                       # MB, ETMR, PINEO, OTHER, ATRT
    kind: str = None                        # molecular group for MB, else the tumor
    atrt_casedef: str = None                # atrt_only | atrt_with_mb_tier2 | mb_reclassified
    gender: str = None
    birthdate: date = None
    age_months: int = None                  # completed months at presentation
    presentation_day: date = None
    surgery_day: date = None
    biopsy_day: date = None
    second_look_day: date = None
    relapse_surgery_day: date = None
    extent: str = None
    residual_cm2: float = None
    m_stage: str = None
    histology: str = None
    transfer: bool = False
    arrival_day: date = None                # first encounter here (= presentation unless transfer)
    methotrexate: bool = False
    protocol: str = None
    radiation_first: bool = False
    chemo_start_day: date = None
    cycles: list = field(default_factory=list)      # (day, [agents]) actually administered
    therapy_end_day: date = None
    upfront_radiation_day: date = None      # radiation given before any event
    upfront_radiation_field: str = None
    salvage_radiation_day: date = None
    salvage_radiation_field: str = None
    cured: bool = None
    toxic_death: bool = False
    event_day: date = None                  # first relapse or progression, the truth
    event_type: str = None
    second_malignancy_day: date = None
    death_day: date = None
    observed_end_day: date = None           # last day this EHR can see the patient
    encounters: list = field(default_factory=list)  # (start, end), sorted, already screened
    screened_out: str = None

    @property
    def metastatic(self) -> bool:
        return self.m_stage != 'M0'

    @property
    def anaplastic(self) -> bool:
        return self.histology == 'LARGE_CELL_ANAPLASTIC'

    @property
    def residual(self) -> bool:
        return self.extent in ('PARTIAL_RESECTION', 'BIOPSY')

    @property
    def recent_era(self) -> bool:
        return self.presentation_day.year >= 2016

    def observed(self, day: date | None) -> bool:
        """
        :return: True when `day` happened where this EHR could see it
        """
        return day is not None and day <= self.observed_end_day

    def radiation_days(self) -> list:
        out = list()
        for day, radiation_field in ((self.upfront_radiation_day, self.upfront_radiation_field),
                                     (self.salvage_radiation_day, self.salvage_radiation_field)):
            if day is not None:
                out.append((day, radiation_field))
        return out


def simulate_truth(rng, index: int) -> Patient:
    pat = Patient(index=index, subject_ref=f'Patient/synth-{index:06d}')
    truth_disease(rng, pat)
    truth_treatment(rng, pat)
    truth_outcome(rng, pat)
    truth_encounters(rng, pat)
    return pat


def truth_disease(rng, pat: Patient) -> None:
    pat.tumor = pick_key(rng, TUMOR_MIX)
    pat.kind = pick_key(rng, MB_GROUP_MIX) if pat.tumor == 'MB' else pat.tumor
    kind = KIND[pat.kind]
    if pat.tumor == 'ATRT':
        pat.atrt_casedef = pick(rng, ['atrt_only', 'atrt_with_mb_tier2', 'mb_reclassified'], [0.40, 0.35, 0.25])

    if rng.random() < kind.p_age_36_to_47:
        age_days = rng.uniform(36, AGE_MONTHS_MAX) * DAYS_PER_MONTH
    else:
        age_days = max(36 * rng.beta(*kind.age_beta), 1.0) * DAYS_PER_MONTH
    #  leave a year of possible follow-up before the extract, the rest is screened by utilization
    span = (EXTRACT_DAY - STUDY_PERIOD_START).days - 200
    pat.presentation_day = STUDY_PERIOD_START + days(rng.integers(0, span))
    pat.birthdate = pat.presentation_day - days(age_days)
    pat.age_months = completed_months(pat.birthdate, pat.presentation_day)
    pat.gender = 'male' if rng.random() < kind.p_male else 'female'

    pat.m_stage = pick(rng, M_STAGES, kind.m_stage)
    pat.extent = pick(rng, EXTENTS, kind.extent)
    if pat.extent == 'NEAR_TOTAL_RESECTION':
        pat.residual_cm2 = round(float(rng.uniform(0.1, 1.5)), 1)       # trial: NTR is under 1.5 cm2
    elif pat.extent in ('PARTIAL_RESECTION', 'BIOPSY'):
        pat.residual_cm2 = round(float(np.clip(rng.lognormal(math.log(4.0), 0.6), 1.6, 30.0)), 1)
    if kind.histology:
        pat.histology = pick(rng, HISTOLOGIES, kind.histology)

    if rng.random() < P_BIOPSY_BEFORE_RESECTION and pat.extent != 'BIOPSY':
        pat.biopsy_day = pat.presentation_day + uniform_days(rng, 0, 2)
        pat.surgery_day = pat.biopsy_day + uniform_days(rng, 4, 12)
    else:
        pat.surgery_day = pat.presentation_day + uniform_days(rng, 0, 4)

    pat.transfer = rng.random() < P_TRANSFER
    pat.arrival_day = pat.presentation_day
    if pat.transfer:
        pat.arrival_day = pat.surgery_day + uniform_days(rng, 50, 240)


def truth_treatment(rng, pat: Patient) -> None:
    older = pat.age_months >= 36
    pat.radiation_first = older and pat.tumor != 'ATRT' and rng.random() < P_RADIATION_FIRST_36_TO_47

    log_odds = MTX_LOG_ODDS['intercept']
    log_odds += MTX_LOG_ODDS['metastatic'] * pat.metastatic
    log_odds += MTX_LOG_ODDS['anaplastic'] * pat.anaplastic
    log_odds += MTX_LOG_ODDS['recent_era'] * pat.recent_era
    log_odds += MTX_LOG_ODDS['under_8_months'] * (pat.age_months < 8)
    log_odds += MTX_LOG_ODDS['atrt'] * (pat.tumor == 'ATRT')
    pat.methotrexate = (not pat.radiation_first) and rng.random() < sigmoid(log_odds)

    if pat.radiation_first:
        protocols = PROTOCOL_RADIATION_FIRST
    elif pat.tumor == 'ATRT':
        protocols = PROTOCOL_ATRT
    elif pat.methotrexate:
        protocols = PROTOCOL_WITH_MTX
    else:
        protocols = PROTOCOL_WITHOUT_MTX
    if rng.random() < P_TREATED_PER_PROTOCOL:
        #  the first protocol listed is the usual one
        pat.protocol = protocols[0] if rng.random() < 0.6 else str(rng.choice(protocols))

    #  the planned schedule. truth_outcome() cuts it at the first event.
    if pat.radiation_first:
        pat.upfront_radiation_day = pat.surgery_day + uniform_days(rng, 25, 42)
        pat.upfront_radiation_field = 'CRANIOSPINAL_WITH_FOCAL_BOOST'
        pat.chemo_start_day = pat.upfront_radiation_day + days(42) + uniform_days(rng, 28, 49)
        day = pat.chemo_start_day
        for _ in range(int(rng.integers(4, 8))):
            pat.cycles.append((day, list(MAINTENANCE)))
            day = day + days(42) + uniform_days(rng, 0, 10)
        pat.therapy_end_day = pat.cycles[-1][0] + days(28)
        return

    #  trial: enrollment within 31 days of definitive surgery
    pat.chemo_start_day = pat.surgery_day + uniform_days(rng, 12, 35)
    day = pat.chemo_start_day
    for _ in range(3):
        agents = list(INDUCTION)
        if pat.methotrexate:
            agents = [METHOTREXATE] + agents
        pat.cycles.append((day, agents))
        day = day + days(21) + uniform_days(rng, 0, 8)
    for _ in range(3):
        pat.cycles.append((day, list(CONSOLIDATION)))
        day = day + days(28) + uniform_days(rng, 0, 10)
    pat.therapy_end_day = day

    p_radiation = P_RADIATION_AFTER_CHEMO['36_to_47' if older else 'under_36']
    if pat.kind == 'SHH':
        p_radiation = p_radiation / 2       # 10 of 11 SHH survivors were never irradiated
    if rng.random() < p_radiation:
        pat.upfront_radiation_day = pat.therapy_end_day + uniform_days(rng, 21, 60)
        pat.upfront_radiation_field = ('CRANIOSPINAL_WITH_FOCAL_BOOST' if older and pat.metastatic
                                       else 'FOCAL_TUMOR_BED')
        pat.therapy_end_day = pat.upfront_radiation_day + days(42)


def truth_outcome(rng, pat: Patient) -> None:
    kind = KIND[pat.kind]
    m_index_prevalence = 1.0 - kind.m_stage[0]
    anaplastic_prevalence = kind.histology[3] if kind.histology else 0.0
    log_odds = logit(kind.efs_without_mtx)
    log_odds += LOG_ODDS_METASTATIC * (pat.metastatic - m_index_prevalence)
    log_odds += LOG_ODDS_ANAPLASTIC * (pat.anaplastic - anaplastic_prevalence)
    log_odds += LOG_ODDS_RESIDUAL * (pat.residual - 0.35)
    log_odds += LOG_ODDS_RECENT_ERA * (pat.recent_era - 0.55)
    log_odds += LOG_ODDS_UPFRONT_RADIATION * pat.radiation_first
    log_odds += kind.mtx_log_odds * pat.methotrexate
    pat.cured = rng.random() < sigmoid(log_odds)

    pat.toxic_death = rng.random() < P_TOXIC_DEATH
    if pat.toxic_death:
        pat.death_day = pat.chemo_start_day + uniform_days(rng, 20, 170)
    elif not pat.cured:
        if rng.random() < P_LATE_RELAPSE:
            months = rng.uniform(RELAPSE_MONTHS_MAX, 48)
        else:
            months = np.clip(rng.lognormal(math.log(kind.relapse_median_months), 0.55), 1.5, RELAPSE_MONTHS_MAX)
        pat.event_day = pat.surgery_day + days(months * DAYS_PER_MONTH)
        on_therapy = pat.event_day < pat.therapy_end_day + days(30)
        pat.event_type = 'PROGRESSION' if on_therapy or rng.random() < 0.25 else 'RECURRENCE'

    first_event_day = pat.event_day or pat.death_day
    if first_event_day:
        cut_therapy_at(pat, first_event_day)

    if pat.event_day:
        p_death = kind.p_death_after_relapse
        if pat.upfront_radiation_day is None and rng.random() < P_SALVAGE_RADIATION:
            pat.salvage_radiation_day = pat.event_day + uniform_days(rng, 14, 45)
            age_at_relapse = completed_months(pat.birthdate, pat.event_day)
            pat.salvage_radiation_field = ('CRANIOSPINAL_WITH_FOCAL_BOOST' if age_at_relapse >= 36
                                           else 'FOCAL_TUMOR_BED')
            p_death -= 0.15
        if rng.random() < 0.20:
            pat.relapse_surgery_day = pat.event_day + uniform_days(rng, 3, 21)
        if rng.random() < p_death:
            pat.death_day = pat.event_day + lognormal_days(rng, DEATH_AFTER_RELAPSE_MEDIAN_DAYS, 0.8, 10, 2500)
            if pat.salvage_radiation_day and pat.salvage_radiation_day >= pat.death_day:
                pat.salvage_radiation_day = None
                pat.salvage_radiation_field = None
            if pat.relapse_surgery_day and pat.relapse_surgery_day >= pat.death_day:
                pat.relapse_surgery_day = None

    if first_event_day is None:
        p_second = P_SECOND_MALIGNANCY * (2 if pat.upfront_radiation_day else 1)
        if rng.random() < p_second:
            pat.second_malignancy_day = pat.surgery_day + days(rng.uniform(4, 9) * 365.25)

    #  where this EHR stops seeing the patient
    lost_day = (pat.therapy_end_day or pat.surgery_day) + days(rng.exponential(365.25 / LOSS_TO_FOLLOWUP_PER_YEAR))
    ninth_birthday_eve = add_years(pat.birthdate, VISIT_AGE_YEARS_MAX) - days(1)
    pat.observed_end_day = min(EXTRACT_DAY, lost_day, ninth_birthday_eve)
    if pat.observed(pat.death_day):
        pat.observed_end_day = pat.death_day


def cut_therapy_at(pat: Patient, first_event_day: date) -> None:
    """
    Initial therapy stops at the first event: later cycles and planned radiation never happen.
    """
    given = list()
    for day, agents in pat.cycles:
        if day < first_event_day:
            given.append((day, agents))
    pat.cycles = given
    if pat.upfront_radiation_day and pat.upfront_radiation_day >= first_event_day:
        pat.upfront_radiation_day = None
        pat.upfront_radiation_field = None
    pat.therapy_end_day = min(pat.therapy_end_day, first_event_day)


def truth_encounters(rng, pat: Patient) -> None:
    """
    Encounters here, already limited to what study_population keeps (visits at ages 0 to 8).
    """
    if not pat.transfer and len(pat.cycles) >= 3 and rng.random() < P_SECOND_LOOK_SURGERY:
        second_look_day = pat.cycles[2][0] + uniform_days(rng, 18, 30)
        first_event_day = pat.event_day or pat.death_day
        if first_event_day is None or second_look_day < first_event_day:
            pat.second_look_day = second_look_day

    visits = list()
    if not pat.transfer:
        if rng.random() < P_PRIOR_HISTORY_HERE:
            day = pat.birthdate + uniform_days(rng, 3, 30)
            while day < pat.presentation_day - days(10):
                visits.append((day, day))
                day = day + uniform_days(rng, 60, 150)
        visits.append((pat.presentation_day, pat.surgery_day + uniform_days(rng, 5, 18)))
    else:
        visits.append((pat.arrival_day, pat.arrival_day + uniform_days(rng, 0, 5)))

    for day, agents in pat.cycles:
        stay = uniform_days(rng, 18, 26) if agents == CONSOLIDATION else uniform_days(rng, 3, 6)
        visits.append((day, day + stay))
    for start_day, _ in pat.radiation_days():
        for week in range(6):
            visits.append((start_day + days(7 * week), start_day + days(7 * week)))
    for day in (pat.second_look_day, pat.relapse_surgery_day):
        if day:
            visits.append((day, day + uniform_days(rng, 3, 8)))

    #  surveillance MRI schedule from the paper: every 3 months in year 1, 4 in year 2, 6 in year 3, then yearly
    day = pat.therapy_end_day + uniform_days(rng, 20, 45)
    while day <= pat.observed_end_day:
        visits.append((day, day))
        years = (day - pat.therapy_end_day).days / 365.25
        if pat.event_day and day >= pat.event_day:
            gap = 45
        elif years < 1:
            gap = 91
        elif years < 2:
            gap = 122
        elif years < 3:
            gap = 183
        else:
            gap = 365
        day = day + days(gap) + uniform_days(rng, -14, 14)

    for day in (pat.event_day, pat.second_malignancy_day):
        if day:
            visits.append((day, day + uniform_days(rng, 2, 10)))
    if pat.death_day and rng.random() < 0.6:
        visits.append((pat.death_day - uniform_days(rng, 0, 10), pat.death_day))

    ninth_birthday = add_years(pat.birthdate, VISIT_AGE_YEARS_MAX)
    kept = dict()
    for start, end in sorted(visits):
        if start < pat.arrival_day and pat.transfer:
            continue
        if start > pat.observed_end_day or start >= ninth_birthday:
            continue
        if start not in kept:
            kept[start] = min(end, pat.observed_end_day)
    pat.encounters = sorted(kept.items())


def upstream_screen(pat: Patient, utilization_screen: bool) -> str | None:
    """
    :return: why the patient never reaches pcx__eligible, None when they do
    """
    if not pat.encounters:
        return 'never_seen_here'            # a transfer who died or was lost before arriving
    span_days = (pat.encounters[-1][1] - pat.encounters[0][0]).days
    if utilization_screen and (len(pat.encounters) < UTILIZATION_ENC_MIN or span_days < UTILIZATION_DAYS_MIN):
        return 'utilization'                # never enters study_population, so no casedef row either
    if pat.atrt_casedef == 'atrt_only':
        return 'atrt_only_casedef'          # in the casedef, but eligible_dx drops ATRT-only subjects
    return None


###############################################################################
# Upstream tables (tests/data/schema.sql)
###############################################################################
class Tables:
    """
    Rows per upstream table, as dicts keyed by the schema.sql column names.
    """
    def __init__(self):
        self.rows = dict()
        self.counter = 0

    def add(self, table: str, **row) -> None:
        self.rows.setdefault(table, list()).append(row)

    def ref(self, resource: str) -> str:
        self.counter += 1
        return f'{resource}/synth-{self.counter:08d}'

    def note(self, pat: Patient, author_day: date) -> str:
        """
        :return: note_ref of a new clinical note, registered with its author date
        """
        note_ref = self.ref('DocumentReference')
        self.add('pcx__sample_casedef_author', subject_ref=pat.subject_ref, note_ref=note_ref,
                 note_author_date=author_day)
        return note_ref


def load_casedef_codes() -> dict:
    """
    :return: {(subtype, tier): [(code, display), ...]} from spreadsheet/casedef.csv, so codes never drift
    """
    codes = dict()
    with open(filetool.path_spreadsheet('casedef.csv'), newline='', encoding='utf-8-sig') as f:
        for row in csv.DictReader(f):
            codes.setdefault((row['subtype'], int(row['tier'])), list()).append((row['code'], row['display']))
    return codes


# A casedef display that names a molecular group or histology only fits the matching patient.
SPECIFIC_DISPLAY = {'non-shh': ['G3', 'G4'], 'shh': ['SHH'], 'wnt': ['WNT'], 'group 3': ['G3'], 'group 4': ['G4'],
                    'desmoplastic': ['DESMOPLASTIC_NODULAR'], 'large cell': ['LARGE_CELL_ANAPLASTIC'],
                    'anaplastic': ['LARGE_CELL_ANAPLASTIC'], 'relapsed': [], 'history': []}


def pick_casedef_code(rng, candidates: list, pat: Patient) -> str:
    """
    :return: a code whose display does not contradict the patient (generic codes fit everyone)
    """
    fitting = list()
    for code, display in candidates:
        fits = True
        for phrase, allowed in SPECIFIC_DISPLAY.items():
            if phrase in display.lower():
                fits = pat.kind in allowed or pat.histology in allowed
                break
        if fits:
            fitting.append(code)
    if not fitting:
        fitting = [code for code, _ in candidates]
    return str(rng.choice(fitting))


def draw_precision(noise: Noise) -> str | None:
    """
    :return: DAY, MONTH, YEAR, or None when the note gives no date at all
    """
    if noise.hit('llm_date_missing'):
        return None
    if noise.hit('llm_date_year_precision'):
        return 'YEAR'
    if noise.hit('llm_date_month_precision'):
        return 'MONTH'
    return 'DAY'


def format_llm_date(day: date | None, precision: str | None) -> tuple:
    """
    :return: (ISO date, precision) the way a note states it. Coarse dates are first-of-period.
    """
    if day is None or precision is None:
        return None, None
    if precision == 'YEAR':
        day = day.replace(month=1, day=1)
    if precision == 'MONTH':
        day = day.replace(day=1)
    return day.isoformat(), precision


def llm_date(noise: Noise, day: date | None) -> tuple:
    return format_llm_date(day, draw_precision(noise))


def spell_agent(noise: Noise, agent: str) -> str:
    usual, variant, abbreviation = AGENT_SPELLING[agent]
    if noise.hit('llm_agent_abbreviated'):
        return abbreviation
    return usual if noise.rng.random() < 0.75 else variant


def author_day_for(noise: Noise, pat: Patient, *stated_days) -> date:
    """
    A note is written on or after everything it states, except for the rare extraction error.
    """
    latest = max(day for day in stated_days if day is not None)
    if noise.hit('llm_date_after_note'):
        return latest - days(noise.rng.integers(2, 30))
    return min(latest + days(noise.rng.integers(0, 4)), max(pat.observed_end_day, latest))


def emit_patient(pat: Patient, noise: Noise, tables: Tables, casedef_codes: dict) -> bool:
    """
    :return: True when the subject lands in pcx__eligible
    """
    has_core_patient = emit_demographics(pat, noise, tables)
    emit_encounters(pat, noise, tables)
    emit_casedef(pat, noise, tables, casedef_codes)
    emit_diagnosis(pat, noise, tables)
    emit_surgery(pat, noise, tables)
    emit_chemotherapy(pat, noise, tables)
    emit_radiation(pat, noise, tables)
    emit_events_and_vital_status(pat, noise, tables, has_core_patient)
    return has_core_patient


def emit_demographics(pat: Patient, noise: Noise, tables: Tables) -> bool:
    if noise.hit('core_patient_row_missing'):
        return False
    tables.add('core__patient', subject_ref=pat.subject_ref,
               birthdate=None if noise.hit('birthdate_missing') else pat.birthdate,
               gender=None if noise.hit('gender_missing') else pat.gender)
    return True


def emit_encounters(pat: Patient, noise: Noise, tables: Tables) -> None:
    visits = list(pat.encounters)
    if pat.observed(pat.death_day) and noise.hit('encounter_after_death'):
        billing_day = pat.death_day + days(noise.rng.integers(5, 40))       # bereavement or billing visit
        if billing_day <= EXTRACT_DAY:
            visits.append((billing_day, billing_day))
    for ordinal, (start, end) in enumerate(visits, start=1):
        end_missing = noise.hit('study_period_end_missing')
        tables.add('pcx__cohort_study_period', subject_ref=pat.subject_ref, period_ordinal=ordinal,
                   period_start_day=start, period_end_day=None if end_missing else end,
                   encounter_ref=tables.ref('Encounter'))
        tables.add('pcx__cohort_study_population', subject_ref=pat.subject_ref, enc_period_ordinal=ordinal,
                   enc_period_start_day=start, enc_period_end_day_filled=start if end_missing else end)


def emit_casedef(pat: Patient, noise: Noise, tables: Tables, casedef_codes: dict) -> None:
    """
    pcx__cohort_casedef is one row per encounter and case-definition code. The first tier 1
    medulloblastoma encounter becomes t0_day in pcx__eligible_dx.
    """
    rng = noise.rng
    first_day = pat.encounters[0][0] if pat.transfer else pat.presentation_day
    visits = [start for start, _ in pat.encounters if start >= first_day]
    oncology_visits = [start for start in visits if start >= pat.surgery_day + days(7)]

    #  when does the specific (tier 1) diagnosis first get coded?
    tier1_from = first_day
    if noise.hit('casedef_tier1_late'):
        late = [start for start in visits if start >= first_day + days(90)]
        tier1_from = late[0] if late else None
    elif not pat.transfer and oncology_visits and rng.random() < 0.45:
        tier1_from = oncology_visits[0]         # coded at the first oncology admission, not at presentation
    if noise.hit('casedef_tier2_only'):
        tier1_from = None

    plan = list()                               # (subtype, tier, from_day, until_day)
    subtype = CASEDEF_SUBTYPE[pat.tumor]
    if pat.tumor == 'ATRT':
        plan.append(('atrt', 1, tier1_from, None))
        if pat.atrt_casedef == 'atrt_with_mb_tier2':
            plan.append(('medulloblastoma', 2, first_day, None))
        elif pat.atrt_casedef == 'mb_reclassified':
            reclassified = first_day + days(rng.integers(10, 45))       # INI1 result comes back
            plan = [('medulloblastoma', 1, first_day, reclassified), ('atrt', 1, reclassified, None)]
    else:
        if (subtype, 1) in casedef_codes and (pat.tumor == 'MB' or rng.random() < 0.6):
            plan.append((subtype, 1, tier1_from, None))
        plan.append((subtype, 2, first_day, None))

    rows = list()
    for subtype, tier, from_day, until_day in plan:
        if from_day is None:
            continue
        code = pick_casedef_code(rng, casedef_codes[(subtype, tier)], pat)
        recorded_first_day = None
        for start in visits:
            if start < from_day or (until_day and start >= until_day):
                continue
            first = recorded_first_day is None
            p_coded = 0.6 if tier == 1 else 0.2
            if first or rng.random() < p_coded:
                rows.append((subtype, tier, code, start))
                recorded_first_day = recorded_first_day or start
        if recorded_first_day:
            #  onset is the clinician-entered date, so a transfer's onset predates every encounter here
            onset_day = pat.presentation_day if rng.random() < 0.5 else None
            tables.add('pcx__cohort_casedef_dx', subject_ref=pat.subject_ref, subtype=subtype, tier=tier,
                       dx_onset_date=onset_day, dx_recorded_date=recorded_first_day)
    if not rows:
        return
    anchor_day = min(start for _, _, _, start in rows)
    for subtype, tier, code, start in rows:
        tables.add('pcx__cohort_casedef', subject_ref=pat.subject_ref, subtype=subtype, tier=tier, code=code,
                   enc_period_start_day=start, enc_period_start_day_min=anchor_day)


def note_days_after(pat: Patient, rng, earliest: date, count: int) -> list:
    """
    :return: up to `count` encounter days on or after `earliest`, where a note could be written
    """
    candidates = [start for start, _ in pat.encounters if start >= earliest]
    if not candidates:
        return list()
    #  the first note is written at the first chance, later ones any time during follow-up
    chosen = {0} | {int(i) for i in rng.choice(len(candidates), size=min(count, len(candidates)) - 1, replace=False)}
    return sorted(candidates[i] for i in chosen)


def emit_diagnosis(pat: Patient, noise: Noise, tables: Tables) -> None:
    rng = noise.rng
    if noise.hit('llm_diagnosis_missing'):
        return
    note_days = note_days_after(pat, rng, max(pat.surgery_day, pat.arrival_day), 1 + min(int(rng.poisson(1.0)), 3))
    for position, note_day in enumerate(note_days):
        subtype = LLM_SUBTYPE[pat.tumor]
        if pat.tumor in ('ETMR', 'OTHER') and not pat.recent_era and rng.random() < 0.65:
            subtype = 'LEGACY_SPNET'                        # "PNET" before WHO 2016
        if pat.atrt_casedef == 'mb_reclassified' and position == 0:
            subtype = 'MEDULLOBLASTOMA'                     # first read, before INI1
        if noise.hit('llm_subtype_not_stated'):
            subtype = NONE_OF_THE_ABOVE
        elif noise.hit('llm_subtype_wrong'):
            subtype = 'ATRT' if subtype == 'MEDULLOBLASTOMA' else 'MEDULLOBLASTOMA'

        histology = NONE_OF_THE_ABOVE
        if pat.histology and subtype == 'MEDULLOBLASTOMA' and not noise.hit('llm_histology_not_stated'):
            histology = pat.histology
        m_stage = NONE_OF_THE_ABOVE if noise.hit('llm_m_stage_not_stated') else pat.m_stage

        stated_day = pat.presentation_day if rng.random() < 0.6 else pat.surgery_day
        gold_day = pat.surgery_day if rng.random() < 0.7 else pat.surgery_day + days(rng.integers(1, 7))
        diagnosis_date, diagnosis_precision = llm_date(noise, stated_day)
        gold_date, gold_precision = llm_date(noise, gold_day)

        age_months = None
        if not noise.hit('llm_age_not_stated'):
            age_months = pat.age_months
            if noise.hit('llm_age_wrong'):
                age_months = max(age_months + int(rng.choice([-1, 1])) * int(rng.integers(4, 13)), 0)

        note_ref = tables.note(pat, author_day_for(noise, pat, note_day, gold_day))
        tables.add('pcx__llm_diagnosis_wide', subject_ref=pat.subject_ref, note_ref=note_ref,
                   disease_subtype=subtype, medulloblastoma_histology=histology, chang_m_stage=m_stage,
                   diagnosis_date=diagnosis_date, diagnosis_date_precision=diagnosis_precision,
                   diagnosis_date_gold=gold_date, diagnosis_date_gold_precision=gold_precision,
                   age_at_diagnosis_months=age_months)


def emit_surgery(pat: Patient, noise: Noise, tables: Tables) -> None:
    rng = noise.rng
    operations = list()                     # (day, surgery_type, extent, residual_cm2, craniotomy tier)
    if pat.biopsy_day:
        operations.append((pat.biopsy_day, 'STEREOTACTIC_BIOPSY', 'BIOPSY', None, 2))
    if pat.extent == 'BIOPSY':
        operations.append((pat.surgery_day, 'STEREOTACTIC_BIOPSY', 'BIOPSY', pat.residual_cm2, 2))
    else:
        operations.append((pat.surgery_day, 'CRANIOTOMY', pat.extent, pat.residual_cm2, 1))
    if pat.second_look_day:
        operations.append((pat.second_look_day, 'CRANIOTOMY', 'GROSS_TOTAL_RESECTION', None, 1))
    if pat.observed(pat.relapse_surgery_day):
        extent = pick(rng, EXTENTS[:3], [0.5, 0.2, 0.3])
        operations.append((pat.relapse_surgery_day, 'CRANIOTOMY', extent, None, 1))

    llm_missing = noise.hit('llm_surgery_missing')
    proc_missing = noise.hit('proc_craniotomy_missing')
    for day, surgery_type, extent, residual_cm2, tier in operations:
        here = day >= pat.arrival_day
        if here and not proc_missing:
            tables.add('pcx__cohort_proc_craniotomy', subject_ref=pat.subject_ref,
                       proc_performed_day=None if noise.hit('proc_craniotomy_undated') else day,
                       procedure_ref=tables.ref('Procedure'), tier=str(tier))
        if llm_missing:
            continue
        #  the operative note, and half the time the oncology consult repeats it
        for _ in range(1 + int(rng.random() < 0.5)):
            stated_day = day
            if noise.hit('llm_surgery_date_wrong'):
                stated_day = day + int(rng.choice([-1, 1])) * days(rng.integers(15, 41))
            surgery_date, precision = llm_date(noise, stated_day)
            stated_extent = NONE_OF_THE_ABOVE if noise.hit('llm_extent_not_stated') else extent
            age = None
            if rng.random() < 0.5:
                age = round((day - pat.birthdate).days / DAYS_PER_MONTH, 1)
            area = residual_cm2 if residual_cm2 and rng.random() < 0.7 else None
            note_ref = tables.note(pat, author_day_for(noise, pat, max(day, pat.arrival_day), stated_day))
            tables.add('pcx__llm_surgery_wide', subject_ref=pat.subject_ref, note_ref=note_ref,
                       age_at_surgery_months=age, residual_tumor_area_cm2=area, surgery_type=surgery_type,
                       extent_of_resection=stated_extent, surgery_date=surgery_date,
                       surgery_date_precision=precision)
    if rng.random() < 0.3 and not pat.transfer and not proc_missing:
        #  shunt or ventriculostomy for hydrocephalus: a tier 3 craniotomy-table row, never definitive
        tables.add('pcx__cohort_proc_craniotomy', subject_ref=pat.subject_ref,
                   proc_performed_day=pat.presentation_day + days(rng.integers(0, 3)),
                   procedure_ref=tables.ref('Procedure'), tier='3')


def emit_chemotherapy(pat: Patient, noise: Noise, tables: Tables) -> None:
    rng = noise.rng
    #  orders exist only for cycles given here
    if not noise.hit('rx_orders_missing'):
        for day, agents in pat.cycles:
            if day < pat.arrival_day:
                continue
            for agent in agents:
                variable = 'rx_contrast_methotrexate' if agent == METHOTREXATE else f'rx_chemo_{agent}'
                tables.add('pcx__cohort_variable_union_rx', subject_ref=pat.subject_ref, variable=variable,
                           rx_authoredon_date=day + days(rng.integers(0, 2)))
    if not pat.methotrexate and pat.cycles and noise.hit('rx_methotrexate_order_never_given'):
        tables.add('pcx__cohort_variable_union_rx', subject_ref=pat.subject_ref,
                   variable='rx_contrast_methotrexate', rx_authoredon_date=max(pat.cycles[0][0], pat.arrival_day))

    protocol_name = None
    if pat.protocol and not noise.hit('llm_protocol_not_stated'):
        protocol_name = str(rng.choice(PROTOCOL_SPELLING)).format(pat.protocol)
    if pat.cycles and (protocol_name or rng.random() < 0.5):
        tables.add('pcx__llm_systemic_therapy_regimen', subject_ref=pat.subject_ref,
                   protocol_name_verbatim=protocol_name)
    if pat.protocol and rng.random() < 0.25:
        tables.add('pcx__llm_survival_timeline_anchor', subject_ref=pat.subject_ref, protocol_name=pat.protocol)

    if not pat.cycles or noise.hit('llm_agents_missing'):
        return
    first_given = dict()                    # agent -> first administration day
    for day, agents in pat.cycles:
        for agent in agents:
            first_given.setdefault(agent, day)

    if rng.random() < 0.4 and not pat.transfer:
        #  the oncology consult lists the plan before anything is given
        note_ref = tables.note(pat, pat.chemo_start_day - days(rng.integers(1, 8)))
        for agent in pat.cycles[0][1]:
            start_date, precision = llm_date(noise, pat.chemo_start_day)
            tables.add('pcx__llm_systemic_therapy_agent', subject_ref=pat.subject_ref, note_ref=note_ref,
                       delivery_status='PLANNED', agent_name=spell_agent(noise, agent),
                       therapy_start_date=start_date, therapy_start_date_precision=precision)

    for note_day in note_days_after(pat, rng, max(pat.chemo_start_day, pat.arrival_day), int(rng.integers(1, 4))):
        note_ref = None
        note_precision = draw_precision(noise)      # one note states all its dates the same way
        for agent, given_day in first_given.items():
            if given_day > note_day:
                continue
            note_ref = note_ref or tables.note(pat, author_day_for(noise, pat, note_day))
            start_date, precision = format_llm_date(given_day, note_precision)
            tables.add('pcx__llm_systemic_therapy_agent', subject_ref=pat.subject_ref, note_ref=note_ref,
                       delivery_status='ADMINISTERED', agent_name=spell_agent(noise, agent),
                       therapy_start_date=start_date, therapy_start_date_precision=precision)
            if agent == METHOTREXATE and given_day < note_day and noise.hit('llm_leucovorin_named'):
                rescue_date, precision = format_llm_date(given_day + days(1), note_precision)
                tables.add('pcx__llm_systemic_therapy_agent', subject_ref=pat.subject_ref, note_ref=note_ref,
                           delivery_status='ADMINISTERED', agent_name='leucovorin',
                           therapy_start_date=rescue_date, therapy_start_date_precision=precision)


def emit_radiation(pat: Patient, noise: Noise, tables: Tables) -> None:
    rng = noise.rng
    courses = [(day, radiation_field) for day, radiation_field in pat.radiation_days() if pat.observed(day)]
    if pat.transfer and rng.random() < P_TRANSFER_PRIOR_RADIATION and pat.age_months >= 24:
        #  irradiated elsewhere before arriving: prior radiation, known only from notes and history codes
        prior_day = pat.surgery_day + days(rng.integers(30, 50))
        if prior_day < pat.arrival_day:
            courses.insert(0, (prior_day, 'FOCAL_TUMOR_BED'))
            if rng.random() < 0.5:
                tables.add('pcx__cohort_dx_radiation', subject_ref=pat.subject_ref, dx_recorded_date=pat.arrival_day,
                           tier='2', condition_ref=tables.ref('Condition'))

    first_radiation_day = courses[0][0] if courses else None
    structured_missing = noise.hit('radiation_structured_missing')
    llm_missing = noise.hit('llm_radiation_missing')
    for start_day, radiation_field in courses:
        here = start_day >= pat.arrival_day
        if here and not structured_missing:
            for week in range(6):           # weekly treatment management over about 30 fractions
                tables.add('pcx__cohort_proc_radiation', subject_ref=pat.subject_ref,
                           proc_performed_day=start_day + days(7 * week), tier='1')
            if rng.random() < 0.4:
                tables.add('pcx__cohort_dx_radiation', subject_ref=pat.subject_ref, dx_recorded_date=start_day,
                           tier='1', condition_ref=tables.ref('Condition'))
            if rng.random() < 0.3 and start_day + days(120) <= pat.observed_end_day:
                tables.add('pcx__cohort_dx_radiation', subject_ref=pat.subject_ref,
                           dx_recorded_date=start_day + days(120), tier='2', condition_ref=tables.ref('Condition'))
        if llm_missing:
            continue
        method = pick(rng, ['PROTON', 'PHOTON', 'IMRT', NONE_OF_THE_ABOVE],
                      [0.55, 0.15, 0.20, 0.10] if start_day.year >= 2012 else [0.10, 0.50, 0.30, 0.10])
        if here and rng.random() < 0.3:
            note_ref = tables.note(pat, max(start_day - days(rng.integers(7, 21)), pat.arrival_day))
            start_date, precision = llm_date(noise, start_day)
            tables.add('pcx__llm_radiation_wide', subject_ref=pat.subject_ref, note_ref=note_ref,
                       delivery_status='PLANNED', radiation_field=radiation_field, radiation_method=method,
                       radiation_start_date=start_date, radiation_start_date_precision=precision)
        #  the treatment summary is written after the course, while the patient is still seen here
        summary_day = min(start_day + days(rng.integers(30, 90)), pat.observed_end_day)
        note_ref = tables.note(pat, author_day_for(noise, pat, summary_day, start_day, pat.arrival_day))
        start_date, precision = llm_date(noise, start_day)
        tables.add('pcx__llm_radiation_wide', subject_ref=pat.subject_ref, note_ref=note_ref,
                   delivery_status='ADMINISTERED', radiation_field=radiation_field, radiation_method=method,
                   radiation_start_date=start_date, radiation_start_date_precision=precision)

    #  "radiation deferred given age": written while the child has not been irradiated (yet)
    unirradiated_until = first_radiation_day or pat.observed_end_day
    candidates = [start for start, _ in pat.encounters
                  if pat.surgery_day + days(14) <= start < unirradiated_until - days(30)]
    #  a child who is going to be irradiated is more often described as "deferred" than "not received"
    stated = rng.random() < (P_NOT_RECEIVED_NOTE_BEFORE_RADIATION if first_radiation_day else 1.0)
    if candidates and stated and not llm_missing and not noise.hit('llm_radiation_not_received_not_stated'):
        note_ref = tables.note(pat, candidates[int(rng.integers(0, len(candidates)))])
        tables.add('pcx__llm_radiation_wide', subject_ref=pat.subject_ref, note_ref=note_ref,
                   delivery_status='EXPLICITLY_NOT_RECEIVED', radiation_field=NONE_OF_THE_ABOVE,
                   radiation_method=NONE_OF_THE_ABOVE, radiation_start_date=None,
                   radiation_start_date_precision=None)


def emit_events_and_vital_status(pat: Patient, noise: Noise, tables: Tables, has_core_patient: bool) -> None:
    rng = noise.rng

    def add_event(event_type: str, event_day: date | None, author_day: date) -> None:
        event_date, precision = llm_date(noise, event_day)
        note_ref = tables.note(pat, author_day_for(noise, pat, author_day, event_day))
        tables.add('pcx__llm_event_wide', subject_ref=pat.subject_ref, note_ref=note_ref, event_type=event_type,
                   event_date=event_date, event_date_precision=precision)

    if rng.random() < 0.7:
        add_event('INITIAL_DIAGNOSIS', pat.presentation_day, max(pat.surgery_day, pat.arrival_day))
    #  complete response at the end of consolidation, about half of evaluable patients
    if len(pat.cycles) == 6 and pat.observed(pat.therapy_end_day) and rng.random() < 0.5:
        add_event('REMISSION', pat.therapy_end_day, pat.therapy_end_day)

    if pat.observed(pat.event_day) and not noise.hit('llm_event_missing'):
        undated = noise.hit('llm_event_undated')
        for _ in range(int(rng.integers(1, 3))):
            add_event(pat.event_type, None if undated else pat.event_day, pat.event_day)
        if noise.hit('llm_event_two_types_same_day'):
            other_type = 'RECURRENCE' if pat.event_type == 'PROGRESSION' else 'PROGRESSION'
            add_event(other_type, pat.event_day, pat.event_day)
    if pat.observed(pat.second_malignancy_day):
        add_event('SECOND_MALIGNANCY', pat.second_malignancy_day, pat.second_malignancy_day)

    died_here = pat.observed(pat.death_day)
    if died_here and rng.random() < 0.5:
        add_event('DECEASED', pat.death_day, pat.death_day)

    #  raw FHIR Patient: deceasedBoolean / deceasedDateTime
    if has_core_patient:
        deceased_flag = None if rng.random() < 0.8 else False
        deceased_datetime = None
        if died_here and not noise.hit('fhir_deceased_flag_missing'):
            deceased_flag = True
            if not noise.hit('fhir_death_date_missing'):
                fhir_death_day = pat.death_day
                if noise.hit('fhir_death_date_wrong'):
                    fhir_death_day = pat.death_day + days(rng.integers(1, 4))
                deceased_datetime = f'{fhir_death_day.isoformat()} 00:00:00'
        tables.add('patient', id=pat.subject_ref.split('/')[1], deceasedBoolean=deceased_flag,
                   deceasedDateTime=deceased_datetime)

    #  survival_timeline task: ALIVE in a few late notes, DECEASED in the death summary
    alive_until = pat.death_day - days(1) if died_here else pat.observed_end_day
    late_visits = [start for start, _ in pat.encounters if start <= alive_until][-int(rng.integers(1, 4)):]
    for visit_day in late_visits:
        if rng.random() < 0.7:
            alive_date, precision = llm_date(noise, visit_day)
            tables.add('pcx__llm_survival_timeline_wide', subject_ref=pat.subject_ref,
                       note_ref=tables.note(pat, author_day_for(noise, pat, visit_day)), vital_status='ALIVE',
                       death_date=None, death_date_precision=None,
                       last_known_alive_date=alive_date, last_known_alive_date_precision=precision)
    if died_here and not noise.hit('llm_death_missing'):
        llm_death_day = pat.death_day
        if noise.hit('llm_death_date_wrong'):
            llm_death_day = pat.death_day + int(rng.choice([-1, 1])) * days(rng.integers(1, 3))
        death_date, precision = llm_date(noise, llm_death_day)
        tables.add('pcx__llm_survival_timeline_wide', subject_ref=pat.subject_ref,
                   note_ref=tables.note(pat, author_day_for(noise, pat, pat.death_day, llm_death_day)),
                   vital_status='DECEASED', death_date=death_date, death_date_precision=precision,
                   last_known_alive_date=None, last_known_alive_date_precision=None)


###############################################################################
# Cohort: simulate until --patients subjects land in pcx__eligible
###############################################################################
def simulate_cohort(patients: int, seed: int, noise_scale: float, utilization_screen: bool = True) -> tuple:
    """
    :return: (Tables, [Patient in pcx__eligible], [every simulated Patient], {screen reason: count})
    """
    casedef_codes = load_casedef_codes()
    tables = Tables()
    tables.rows['pcx__include_study_period'] = list(INCLUDE_STUDY_PERIOD)
    tables.rows['pcx__include_utilization'] = list(INCLUDE_UTILIZATION)
    eligible = list()
    simulated = list()
    screened = dict()
    index = 0
    while len(eligible) < patients:
        index += 1
        #  one stream per patient and purpose: the truth of patient N does not depend on --noise
        truth_rng = np.random.default_rng([seed, index, 0])
        noise = Noise(np.random.default_rng([seed, index, 1]), noise_scale)
        pat = simulate_truth(truth_rng, index)
        simulated.append(pat)
        pat.screened_out = upstream_screen(pat, utilization_screen)
        if pat.screened_out in ('never_seen_here', 'utilization'):
            screened[pat.screened_out] = screened.get(pat.screened_out, 0) + 1
            continue
        in_eligible = emit_patient(pat, noise, tables, casedef_codes)
        if pat.screened_out:
            screened[pat.screened_out] = screened.get(pat.screened_out, 0) + 1
        elif not in_eligible:
            screened['core_patient_row_missing'] = screened.get('core_patient_row_missing', 0) + 1
        else:
            eligible.append(pat)
    return tables, eligible, simulated, screened


###############################################################################
# DuckDB build with the study's real SQL
###############################################################################
def list_stage_sql() -> list[Path]:
    """
    :return: custom/ SQL files in the order eligible.toml then outcome.toml build them
    """
    files = list()
    for stage in STAGES:
        with open(filetool.path_project(stage), 'rb') as f:
            for action in tomllib.load(f)['actions']:
                for filename in action['files']:
                    if filename.startswith('custom/'):
                        files.append(filetool.path_project(filename))
    return files


def write_plain_csv(path: Path, columns: list[str], rows: list[dict]) -> None:
    """
    Upstream tables in the same plain style as the tests/data/warn fixtures (NULL is empty).
    """
    with open(path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        for row in rows:
            unknown = set(row) - set(columns)
            if unknown:
                raise KeyError(f'{path.stem}: columns not in schema.sql: {sorted(unknown)}')
            writer.writerow(['' if row.get(col) is None else row.get(col) for col in columns])


def build_database(tables: Tables, input_dir: Path) -> duckdb.DuckDBPyConnection:
    con = duckdb.connect()
    #  Athena (Trino) semantics the study SQL relies on
    con.execute("CREATE MACRO array_join(a, s) AS list_aggregate(a, 'string_agg', s)")
    con.execute("CREATE MACRO date_diff(part, a, b) AS datesub(part, a, b)")    # completed months, not boundaries
    con.execute(filetool.path_tests_data('schema.sql').read_text())
    schema_tables = [row[0] for row in con.execute('SHOW TABLES').fetchall()]
    unknown = set(tables.rows) - set(schema_tables)
    if unknown:
        raise KeyError(f'tables not in schema.sql: {sorted(unknown)}')
    for table in schema_tables:
        columns = [row[0] for row in con.execute(f'DESCRIBE {table}').fetchall()]
        csv_file = input_dir / f'{table}.csv'
        write_plain_csv(csv_file, columns, tables.rows.get(table, list()))
        con.execute(f"COPY {table} FROM '{csv_file}' (HEADER, DELIMITER ',', NULLSTR '')")
    for sql_file in list_stage_sql():
        con.execute(sql_file.read_text())
    return con


###############################################################################
# Athena-style CSV export
###############################################################################
def athena_text(value) -> str | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return 'true' if value else 'false'
    return str(value)


def export_athena_csv(con: duckdb.DuckDBPyConnection, table: str, path: Path) -> int:
    """
    Athena console/S3 download format: every value double-quoted, NULL as an empty unquoted
    field, booleans true/false, dates YYYY-MM-DD. Rows are ordered for reproducible diffs.
    :return: row count
    """
    cursor = con.execute(f'SELECT * FROM {table} ORDER BY subject_ref')
    columns = [col[0] for col in cursor.description]
    rows = cursor.fetchall()
    with open(path, 'w', newline='', encoding='utf-8') as f:
        f.write(','.join(f'"{col}"' for col in columns) + '\n')
        for row in rows:
            fields = list()
            for value in row:
                text = athena_text(value)
                fields.append('' if text is None else '"' + text.replace('"', '""') + '"')
            f.write(','.join(fields) + '\n')
    return len(rows)


TRUTH_COLUMNS = ['subject_ref', 'tumor', 'molecular_group', 'gender', 'age_months_at_presentation', 'm_stage',
                 'extent_of_resection', 'histology', 'transfer', 'methotrexate', 'protocol', 'radiation_first',
                 'presentation_day', 'surgery_day', 'chemo_start_day', 'upfront_radiation_day',
                 'salvage_radiation_day', 'cured', 'toxic_death', 'event_day', 'event_type',
                 'second_malignancy_day', 'death_day', 'observed_end_day']


def write_truth(path: Path, eligible: list[Patient]) -> None:
    rows = list()
    for pat in eligible:
        rows.append({'subject_ref': pat.subject_ref, 'tumor': pat.tumor,
                     'molecular_group': pat.kind if pat.tumor == 'MB' else None, 'gender': pat.gender,
                     'age_months_at_presentation': pat.age_months, 'm_stage': pat.m_stage,
                     'extent_of_resection': pat.extent, 'histology': pat.histology,
                     'transfer': str(pat.transfer).lower(), 'methotrexate': str(pat.methotrexate).lower(),
                     'protocol': pat.protocol, 'radiation_first': str(pat.radiation_first).lower(),
                     'presentation_day': pat.presentation_day, 'surgery_day': pat.surgery_day,
                     'chemo_start_day': pat.chemo_start_day, 'upfront_radiation_day': pat.upfront_radiation_day,
                     'salvage_radiation_day': pat.salvage_radiation_day, 'cured': str(pat.cured).lower(),
                     'toxic_death': str(pat.toxic_death).lower(), 'event_day': pat.event_day,
                     'event_type': pat.event_type, 'second_malignancy_day': pat.second_malignancy_day,
                     'death_day': pat.death_day, 'observed_end_day': pat.observed_end_day})
    write_plain_csv(path, TRUTH_COLUMNS, rows)


###############################################################################
# Calibration report
###############################################################################
def kaplan_meier(durations: list, events: list, at_days: int) -> float | None:
    """
    :return: Kaplan-Meier survival probability at `at_days`, None without subjects
    """
    if not durations:
        return None
    survival = 1.0
    at_risk = len(durations)
    for duration, event in sorted(zip(durations, events), key=lambda item: (item[0], not item[1])):
        if duration > at_days:
            break
        if event:
            survival *= 1.0 - 1.0 / at_risk
        at_risk -= 1
    return survival


def share(con, table: str, condition: str) -> str:
    total, hits = con.execute(f'SELECT COUNT(*), COUNT(*) FILTER (WHERE {condition}) FROM {table}').fetchone()
    return 'n/a' if not total else f'{100.0 * hits / total:5.1f}%'


def percent(value: float | None) -> str:
    return '  n/a' if value is None else f'{100.0 * value:5.1f}%'


def report(con, simulated: list[Patient], screened: dict, row_counts: dict) -> None:
    print('\nRows written')
    for table, count in row_counts.items():
        print(f'  {table:<32}{count:>8}')
    print('\nSimulated but screened out upstream (not in pcx__eligible)')
    for reason, count in sorted(screened.items()):
        print(f'  {reason:<32}{count:>8}')

    print('\npcx__eligible_trial vs ACNS0334 Table 1            synthetic    paper')
    trial = 'pcx__eligible_trial'
    median_age = con.execute(f'SELECT MEDIAN(age_months_at_definitive_surgery) FROM {trial}').fetchone()[0]
    print(f'  median age at surgery, months                  {median_age or 0:8.1f}     23.6')
    for label, condition, paper in (
            ('male', "gender = 'male'", '50.6%'),
            ('metastatic, LLM M1-M3 (NULL counts as no)', 'llm_metastatic_bool', '55.8%'),
            ('anaplastic (NULL counts as no)', 'llm_anaplastic_bool', '13.0%'),
            ('residual disease, partial resection or biopsy', 'llm_residual_disease_bool', '33.8%'),
            ('methotrexate (randomized in the trial)', 'methotrexate_any_bool', '49.4%')):
        print(f'  {label:<48} {share(con, trial, condition)}    {paper}')

    print('\nKaplan-Meier at 5 years from the DERIVED tables: tier 1 medulloblastoma in pcx__eligible_trial')
    print('  (naive: confounded by indication, and survivor-biased unless --no-utilization-screen)')
    rows = con.execute("""
        SELECT  o.methotrexate_prior_to_first_event_bool, o.efs_days, o.efs_event_bool, o.os_days, o.os_event_bool
        FROM    pcx__outcome AS o
        JOIN    pcx__eligible_trial AS t ON t.subject_ref = o.subject_ref
        WHERE   t.medulloblastoma_tier1_bool AND o.efs_days IS NOT NULL AND o.os_days IS NOT NULL""").fetchall()
    for label, keep, paper in (('with methotrexate   ', True, 'EFS 68.2%'), ('without methotrexate', None, 'EFS 45.8%')):
        arm = [row for row in rows if (row[0] is True) == bool(keep)]
        efs = kaplan_meier([row[1] for row in arm], [row[2] for row in arm], 1826)
        os_ = kaplan_meier([row[3] for row in arm], [row[4] for row in arm], 1826)
        print(f'  {label}  n={len(arm):<6} EFS {percent(efs)}   OS {percent(os_)}     paper {paper}')

    print('\nLatent truth, event-free at 5 years by kind and methotrexate: every simulated patient,')
    print('  BEFORE the utilization screen removes early deaths (this is the calibration to the paper)')
    print('  kind     without MTX        with MTX           paper (without / with)')
    paper = {'G3': '33% / 70%', 'SHH': '100% / 100%', 'G4': 'n=2', 'WNT': 'n/a', 'ETMR': '33% / 20%',
             'PINEO': '0% / 17%', 'OTHER': 'n/a', 'ATRT': 'not in trial'}
    for kind_name in KIND:
        cells = list()
        for methotrexate in (False, True):
            group = [pat for pat in simulated if pat.kind == kind_name and pat.methotrexate == methotrexate
                     and not pat.radiation_first]
            event_free = list()
            for pat in group:
                first = min([day for day in (pat.event_day, pat.death_day, pat.second_malignancy_day) if day],
                            default=None)
                event_free.append(first is None or (first - pat.surgery_day).days > 1826)
            rate = sum(event_free) / len(group) if group else None
            cells.append(f'{percent(rate)} (n={len(group):<5})')
        print(f'  {kind_name:<8} {cells[0]}   {cells[1]}    {paper[kind_name]}')


CATEGORICAL_MAX_DISTINCT = 12       # a text column with more distinct values is summarized as a count


def column_summary(con, table: str, column: str, kind: str, rows: int) -> str | None:
    """
    One line describing a column: value shares for categorical text, range for dates,
    median for numbers, distinct count for identifiers. None when there is nothing to say.
    """
    nulls = con.execute(f'SELECT COUNT(*) FROM {table} WHERE {column} IS NULL').fetchone()[0]
    null_text = f'   null {100.0 * nulls / rows:.0f}%' if nulls else ''
    #  LLM dates are ISO text in the schema, the SQL hard-casts them and so does this
    llm_date = kind == 'VARCHAR' and 'date' in column and not column.endswith('_precision')
    if kind in ('DATE', 'TIMESTAMP') or llm_date:
        expression = f'CAST({column} AS DATE)' if llm_date else column
        low, high = con.execute(f'SELECT MIN({expression}), MAX({expression}) FROM {table}').fetchone()
        if low is None:
            return None
        return f'{str(low)[:10]} .. {str(high)[:10]}{null_text}'
    if kind == 'BOOLEAN':
        true_cnt = con.execute(f'SELECT COUNT(*) FROM {table} WHERE {column}').fetchone()[0]
        return f'true {100.0 * true_cnt / rows:.0f}%{null_text}'
    if column.endswith('_ref') or column == 'id':
        return None
    distinct = con.execute(f'SELECT COUNT(DISTINCT {column}) FROM {table}').fetchone()[0]
    if kind in ('BIGINT', 'INTEGER', 'DOUBLE') and distinct > CATEGORICAL_MAX_DISTINCT:
        median = con.execute(f'SELECT MEDIAN({column}) FROM {table}').fetchone()[0]
        return f'median {median:g}{null_text}'
    if distinct > CATEGORICAL_MAX_DISTINCT:
        return f'{distinct} distinct values{null_text}'
    counted = con.execute(f'SELECT {column}, COUNT(*) FROM {table} WHERE {column} IS NOT NULL '
                          f'GROUP BY 1 ORDER BY 2 DESC, 1').fetchall()
    shares = list()
    for value, count in counted:
        shares.append(f'{value} {100.0 * count / rows:.0f}%')
    return '  '.join(shares) + null_text if shares else None


def report_sources(con) -> None:
    """
    The upstream tables the SQL read (schema.sql), as they were generated: the encounter
    criteria verbatim, then row and subject counts and a per-column characteristic for the rest.
    """
    print('\nFrom CSV sources (tables)')
    print('  encounter criteria')
    for table in ('pcx__include_study_period', 'pcx__include_utilization'):
        cursor = con.execute(f'SELECT * FROM {table}')
        columns = [col[0] for col in cursor.description]
        for row in cursor.fetchall():
            pairs = list()
            for column, value in zip(columns, row):
                pairs.append(f'{column}={value}')
            print(f'    {table:<34}' + '  '.join(pairs))

    for (table,) in con.execute('SHOW TABLES').fetchall():
        if table.startswith('pcx__include_') or not (table in ('core__patient', 'patient')
                                                      or table.startswith(('pcx__cohort_', 'pcx__llm_', 'pcx__sample_'))):
            continue
        described = con.execute(f'DESCRIBE {table}').fetchall()
        columns = [(row[0], row[1]) for row in described]
        rows = con.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0]
        subject_column = 'subject_ref' if 'subject_ref' in dict(columns) else 'id'
        subjects = con.execute(f'SELECT COUNT(DISTINCT {subject_column}) FROM {table}').fetchone()[0]
        print(f'  {table:<36}{rows:>8} rows {subjects:>7} subjects')
        if not rows:
            continue
        for column, kind in columns:
            if column == subject_column:
                continue
            summary = column_summary(con, table, column, kind, rows)
            if summary:
                print(f'      {column:<32}{summary}')


###############################################################################
# CLI
###############################################################################
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('output_dir', type=Path, help='directory for the CSV files (created if missing)')
    parser.add_argument('--patients', type=int, default=1000, help='rows in pcx__eligible (default 1000)')
    parser.add_argument('--seed', type=int, default=334, help='random seed (default 334)')
    parser.add_argument('--noise', type=float, default=1.0,
                        help='scale of EHR gaps and disagreements: 0 clean, 1 realistic (default), 2 messy')
    parser.add_argument('--no-utilization-screen', action='store_true',
                        help='keep patients with under 2 encounters or under 365 days of follow-up, which\n'
                             'study_population removes today (early deaths, see limitations.md, workplan 2.7)')
    parser.add_argument('--include-inputs', action='store_true',
                        help='also keep the upstream tables (schema.sql) as plain CSV in OUTPUT_DIR')
    parser.add_argument('--quiet', action='store_true', help='skip the calibration report')
    args = parser.parse_args(argv)
    if args.patients < 1:
        parser.error('--patients must be positive')
    if args.noise < 0:
        parser.error('--noise must be 0 or more')

    output_dir = args.output_dir.expanduser().resolve()
    if output_dir == filetool.path_tests_data_warn().resolve():
        parser.error('tests/data/warn holds the hand-written SQL test fixtures, choose another directory')
    output_dir.mkdir(parents=True, exist_ok=True)

    tables, eligible, simulated, screened = simulate_cohort(args.patients, args.seed, args.noise,
                                                            not args.no_utilization_screen)
    with tempfile.TemporaryDirectory() as scratch:
        con = build_database(tables, output_dir if args.include_inputs else Path(scratch))

    row_counts = dict()
    for sql_file in list_stage_sql():
        row_counts[sql_file.stem] = export_athena_csv(con, sql_file.stem, output_dir / f'{sql_file.stem}.csv')
    write_truth(output_dir / TRUTH_FILENAME, eligible)

    if row_counts['pcx__eligible'] != args.patients:
        raise RuntimeError(f"pcx__eligible has {row_counts['pcx__eligible']} rows, expected {args.patients}")
    if not args.quiet:
        report(con, simulated, screened, row_counts)
    print(f'\nWrote {len(row_counts)} tables and {TRUTH_FILENAME} to {output_dir}')
    if not args.quiet:
        report_sources(con)
    return 0


def make_tests_synthetic(argv: list[str] | None = None) -> int:
    """
    `make-pcx test-synthetic`: regenerate tests/data/synthetic with the upstream tables included.
    Stale CSVs from an earlier, larger run are removed first so the directory is exactly one run.
    :param argv: generator options (--patients, --seed, --noise, --no-utilization-screen, --quiet)
    """
    output_dir = filetool.path_tests_data_synthetic()
    output_dir.mkdir(parents=True, exist_ok=True)
    for stale in output_dir.glob('*.csv'):
        stale.unlink()
    return main([str(output_dir), '--include-inputs'] + list(argv or []))


if __name__ == '__main__':
    raise SystemExit(main())
