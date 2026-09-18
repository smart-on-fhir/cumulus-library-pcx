#!/usr/bin/env python3
"""Synthetic PCX eligible/outcome CSVs; Python >=3.11, standard library only.

python make_synthetic_data.py --patients 1000 --output ./synthetic --seed 42
python make_synthetic_data.py --patients 1000 --output ./synthetic --inputs

Creates current_sql/ and corrected/ with the same ten table schemas.
--patients counts discovery subjects, NOT members of pcx__eligible_trial.
This is a frozen Python port of the 2026-09-17 SQL (resection-based surgery).
It generates test data; it is not a fitted population model or causal analysis.

Corrected policies are explicit in POLICIES. Latent truth is never consulted
by the derivation functions. Both modes consume the SAME observed evidence.
CSV: UTF-8, headers, ISO dates, lowercase true/false, empty field = SQL NULL.
The output directory must not already exist; nothing is overwritten.
"""
from __future__ import annotations

import argparse
import calendar
import csv
import hashlib
import json
import math
import random
import sys
from collections import Counter
from datetime import date, timedelta
from pathlib import Path

VERSION = "pcx-synthetic-1.0"
PAPER = "https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/"
PREFIX = "pcx__"
DAY = timedelta(days=1)
EFS_TYPES = {"PROGRESSION", "RECURRENCE", "SECOND_MALIGNANCY", "DECEASED"}
RESECTIONS = {"GROSS_TOTAL_RESECTION", "NEAR_TOTAL_RESECTION", "PARTIAL_RESECTION"}
CHEMO = {"methotrexate", "cisplatin", "vincristine", "etoposide",
         "cyclophosphamide", "carboplatin", "thiotepa"}

# Paper-derived reference values; these are NOT EHR prevalence estimates.
REFERENCE = {
    "source": PAPER,
    "eligible": 77,
    "clinical_MB": 46,
    "clinical_non_MB": 31,
    "female": 38 / 77,
    "methotrexate_assignment": 38 / 77,
    "MB_molecular_weights": [25, 11, 2, 8],  # G3, SHH, G4, unclassified
    "resection_weights": [39, 12, 26],       # GTR, NTR, partial
    "G3_five_year_EFS": [1 / 3, .70],        # without, with MTX
    "G3_five_year_OS": [.40, .80],
    "MB_five_year_EFS": [.458, .682],
}
POLICIES = {
    "scope": "Both trial tables retain the current PCX MB-only scope; "
             "neither asserts full ACNS0334 eligibility or adequate organ function.",
    "population": "N discovery candidates with non-ATRT coded evidence and a core "
                  "patient row. ATRT mimics also have nonspecific non-ATRT evidence. "
                  "Upstream age/utilization selection is not rerun.",
    "current_sql": "Frozen row-level semantic port, not an Athena execution. "
                   "Preserves NULL-t0 admission, order-based exposure, undated-event "
                   "censoring, event-only death omission from OS, and coarse dates.",
    "corrected_t0": "Same coded MB origin as current SQL; no invented enrollment "
                    "date or fallback for missing time zero.",
    "corrected_receipt": "Administered agents/doses; orders remain visible in order "
                        "columns but do not prove receipt. MTX counts as chemotherapy.",
    "corrected_prior": "Absence of prior evidence is accepted only with known t0. "
                       "Undated/coarse receipt or receipt within the tolerance "
                       "window makes prior-treatment status unknown.",
    "corrected_survival": "Reconcile death across all sources; only DAY precision "
                          "supports exact intervals. Undated/unusable adverse events "
                          "leave first-event timing unknown. No negative intervals.",
    "corrected_EFS": "Censor only at documented event-free follow-up, bounded by "
                     "last-known-alive/death. Unknown follow-up stays unknown.",
    "corrected_trial": "Require known t0 and no observed pre-t0 adverse event, "
                       "in addition to the existing MB/age/ATRT/prior-therapy rules.",
    "noise": "Missingness, date errors, transfer patterns, follow-up loss and all "
             "non-G3 OS probabilities are configurable/illustrative assumptions, "
             "not estimates from the trial.",
    "truth": "Truth/phenotype columns are separate and never used to repair EHR evidence.",
}

# Compact, explicit output contract; derived columns are ordered as in the SQL.
SCHEMAS = {
    "eligible_dx": """subject_ref birthdate gender t0_day t0_source age_months_at_t0
age_under_36_months_at_t0 medulloblastoma_tier1_bool atrt_tier1_bool atrt_first_day
llm_medulloblastoma_bool llm_atrt_bool llm_diagnosis_day_min llm_diagnosis_gold_day_min
llm_age_months_at_diagnosis_gold llm_age_at_diagnosis_months_min llm_metastatic_bool
llm_anaplastic_bool""".split(),
    "eligible_surgery": """subject_ref birthdate definitive_surgery_day
definitive_surgery_source proc_craniotomy_tier1_first_day proc_craniotomy_tier1_cnt
llm_surgery_first_day llm_definitive_surgery_day llm_age_at_definitive_surgery_months
llm_residual_tumor_area_cm2_min llm_residual_tumor_area_cm2_max llm_residual_disease_bool
age_months_at_definitive_surgery age_under_36_months_at_definitive_surgery""".split(),
    "eligible_rx": """subject_ref t0_day methotrexate_first_day methotrexate_order_first_day
methotrexate_administered_first_day chemo_first_day chemo_order_first_day
chemo_administered_first_day methotrexate_any_bool methotrexate_administered_bool
chemo_any_bool chemo_prior_to_t0_bool""".split(),
    "eligible_radiation": """subject_ref t0_day radiation_first_day radiation_proc_first_day
radiation_dx_first_day radiation_administered_first_day radiation_any_bool
radiation_administered_bool llm_craniospinal_bool llm_proton_bool
llm_explicitly_not_received_bool radiation_prior_to_t0_bool""".split(),
    "eligible": """subject_ref gender birthdate t0_day t0_source age_months_at_t0
age_band_at_t0 definitive_surgery_day definitive_surgery_source
age_months_at_definitive_surgery medulloblastoma_tier1_bool llm_medulloblastoma_bool
age_under_36_months_at_definitive_surgery atrt_confirmed_bool no_prior_chemotherapy_bool
no_prior_radiation_bool llm_metastatic_bool llm_anaplastic_bool llm_residual_disease_bool
llm_residual_tumor_area_cm2_max age_under_8_months_at_t0 methotrexate_any_bool
methotrexate_first_day chemo_any_bool chemo_first_day radiation_any_bool
radiation_first_day llm_craniospinal_bool llm_proton_bool""".split(),
    "outcome_vital_status": """subject_ref t0_day deceased_bool death_day
last_known_alive_day fhir_deceased_bool fhir_death_day last_encounter_day
llm_deceased_bool llm_death_day llm_last_known_alive_day""".split(),
    "outcome_first_event": """subject_ref t0_day first_event_day first_event_type
any_event_bool progression_first_day recurrence_first_day second_malignancy_first_day
death_day undated_event_cnt days_t0_to_first_event""".split(),
    "outcome_exposure": """subject_ref t0_day first_event_day first_event_type
methotrexate_first_day chemo_first_day radiation_first_day
methotrexate_prior_to_first_event_bool chemo_prior_to_first_event_bool
radiation_prior_to_first_event_bool initial_therapy_sequence protocol_names""".split(),
    "outcome": """subject_ref gender age_band_at_t0 age_months_at_t0
age_under_36_months_at_definitive_surgery t0_day os_event_bool death_day
last_known_alive_day os_end_day os_days efs_event_bool first_event_day first_event_type
efs_end_day efs_days efs_censor_source methotrexate_prior_to_first_event_bool
radiation_prior_to_first_event_bool initial_therapy_sequence protocol_names
methotrexate_first_day chemo_first_day radiation_first_day""".split(),
}
SCHEMAS["eligible_trial"] = SCHEMAS["eligible"]
TABLE_ORDER = ["eligible_dx", "eligible_surgery", "eligible_rx", "eligible_radiation",
               "eligible", "eligible_trial", "outcome_vital_status",
               "outcome_first_event", "outcome_exposure", "outcome"]

# Minimal upstream columns consumed by these stages, plus date precision.
INPUTS = {
    "core__patient": "subject_ref birthdate gender",
    "patient": "id deceasedBoolean deceasedDateTime",
    "pcx__cohort_casedef": "subject_ref subtype tier enc_period_start_day",
    "pcx__cohort_proc_craniotomy": "subject_ref procedure_ref tier proc_performed_day",
    "pcx__cohort_variable_union_rx": "subject_ref variable rx_authoredon_date",
    "pcx__cohort_proc_radiation": "subject_ref tier proc_performed_day",
    "pcx__cohort_dx_radiation": "subject_ref tier dx_recorded_date",
    "pcx__cohort_study_population": "subject_ref enc_period_end_day_filled",
    "pcx__llm_diagnosis_wide": """subject_ref disease_subtype medulloblastoma_histology
chang_m_stage diagnosis_date diagnosis_date_precision diagnosis_date_gold
diagnosis_date_gold_precision age_at_diagnosis_months""",
    "pcx__llm_surgery_wide": """subject_ref surgery_date surgery_date_precision
extent_of_resection age_at_surgery_months residual_tumor_area_cm2""",
    "pcx__llm_systemic_therapy_agent": """subject_ref agent_name delivery_status
therapy_start_date therapy_start_date_precision""",
    "pcx__llm_radiation_wide": """subject_ref delivery_status radiation_start_date
radiation_start_date_precision radiation_field radiation_method""",
    "pcx__llm_survival_timeline_wide": """subject_ref vital_status death_date
death_date_precision last_known_alive_date last_known_alive_date_precision""",
    "pcx__llm_event_wide": "subject_ref event_type event_date event_date_precision",
    "pcx__llm_systemic_therapy_regimen": "subject_ref protocol_name_verbatim",
    "pcx__llm_survival_timeline_anchor": "subject_ref protocol_name",
    # Corrected-only evidence: deliberately simplified, not a production wide schema.
    "synthetic_administration": "subject_ref agent_name administration_date administration_date_precision",
    "synthetic_event_free_follow_up": "subject_ref assessment_date assessment_date_precision",
}
INPUTS = {k: v.split() for k, v in INPUTS.items()}


def minimum(xs):
    return min((x for x in xs if x is not None), default=None)


def maximum(xs):
    return max((x for x in xs if x is not None), default=None)


def sql_or(xs):
    xs = [x for x in xs if x is not None]
    return any(xs) if xs else None


def lt(a, b):
    return None if a is None or b is None else a < b


def negate(x):
    return None if x is None else not x


def months(a, b):
    """Completed calendar months, including end-of-month adjustment."""
    if a is None or b is None:
        return None
    if b < a:
        return -months(b, a)
    n = (b.year - a.year) * 12 + b.month - a.month
    anniversary = min(a.day, calendar.monthrange(b.year, b.month)[1])
    return n - (b.day < anniversary)


def duration(a, b, corrected):
    if a is None or b is None or (corrected and b < a):
        return None
    return (b - a).days


def field_date(row, key, corrected):
    value = row.get(key)
    if corrected and row.get(key + "_precision", "DAY") != "DAY":
        return None
    return value


def weighted(rng, values, weights):
    return rng.choices(values, weights=weights, k=1)[0]


def subset(name, *parts):
    merged = {}
    for part in parts:
        merged.update(part)
    missing = set(SCHEMAS[name]) - merged.keys()
    if missing:
        raise AssertionError((name, missing))
    return {k: merged[k] for k in SCHEMAS[name]}


def prior_status(days, anchor, tolerance):
    """Unknown if any receipt has unknown date or ambiguous baseline ordering."""
    if anchor is None:
        return None
    if any(d is not None and d < anchor - tolerance * DAY for d in days):
        return True
    if any(d is None or abs((d - anchor).days) <= tolerance for d in days):
        return None
    return False


def derive(e, corrected=False, tolerance=3):
    """Independent deterministic derivation from observed evidence only."""
    get = lambda name: e[PREFIX + name]
    pat = e["core__patient"][0]
    sid, birth = pat["subject_ref"], pat["birthdate"]
    coded = get("cohort_casedef")
    mb = [r for r in coded if r["subtype"] == "medulloblastoma" and r["tier"] == 1]
    atrt = [r for r in coded if r["subtype"] == "atrt" and r["tier"] == 1]
    t0 = minimum(r["enc_period_start_day"] for r in mb)
    diagnoses = get("llm_diagnosis_wide")
    dxday = minimum(field_date(r, "diagnosis_date", corrected) for r in diagnoses)
    gold = minimum(field_date(r, "diagnosis_date_gold", corrected) for r in diagnoses)
    dx = dict(pat, t0_day=t0, t0_source="casedef_tier1_medulloblastoma",
              age_months_at_t0=months(birth, t0),
              age_under_36_months_at_t0=lt(months(birth, t0), 36),
              medulloblastoma_tier1_bool=bool(mb), atrt_tier1_bool=bool(atrt),
              atrt_first_day=minimum(r["enc_period_start_day"] for r in atrt),
              llm_medulloblastoma_bool=sql_or(r["disease_subtype"] == "MEDULLOBLASTOMA" for r in diagnoses),
              llm_atrt_bool=sql_or(r["disease_subtype"] == "ATRT" for r in diagnoses),
              llm_diagnosis_day_min=dxday, llm_diagnosis_gold_day_min=gold,
              llm_age_months_at_diagnosis_gold=months(birth, gold),
              llm_age_at_diagnosis_months_min=minimum(r["age_at_diagnosis_months"] for r in diagnoses),
              llm_metastatic_bool=sql_or(r["chang_m_stage"] in {"M1", "M2", "M3", "M4"} for r in diagnoses),
              llm_anaplastic_bool=sql_or(r["medulloblastoma_histology"] == "LARGE_CELL_ANAPLASTIC" for r in diagnoses))

    procs = [r for r in get("cohort_proc_craniotomy") if r["tier"] == 1]
    ops = get("llm_surgery_wide")
    resections = [r for r in ops if r["extent_of_resection"] in RESECTIONS]
    procday = minimum(r["proc_performed_day"] for r in procs)
    llmday = minimum(field_date(r, "surgery_date", corrected) for r in resections)
    definitive = llmday if llmday is not None else procday
    residual_ops = ops
    if corrected:
        residual_ops = [r for r in ops if definitive is not None
                        and field_date(r, "surgery_date", True) == definitive]
    surg = dict(subject_ref=sid, birthdate=birth,
                definitive_surgery_day=definitive,
                definitive_surgery_source=("llm_surgery_resection" if llmday is not None
                    else "proc_craniotomy_tier1_first" if procday is not None else None),
                proc_craniotomy_tier1_first_day=procday,
                proc_craniotomy_tier1_cnt=len({r["procedure_ref"] for r in procs}) if procs else None,
                llm_surgery_first_day=minimum(field_date(r, "surgery_date", corrected) for r in ops),
                llm_definitive_surgery_day=llmday,
                llm_age_at_definitive_surgery_months=minimum(r["age_at_surgery_months"] for r in resections),
                llm_residual_tumor_area_cm2_min=minimum(r["residual_tumor_area_cm2"] for r in residual_ops),
                llm_residual_tumor_area_cm2_max=maximum(r["residual_tumor_area_cm2"] for r in residual_ops),
                llm_residual_disease_bool=sql_or(r["extent_of_resection"] in {"PARTIAL_RESECTION", "BIOPSY"}
                                               for r in residual_ops),
                age_months_at_definitive_surgery=months(birth, definitive),
                age_under_36_months_at_definitive_surgery=lt(months(birth, definitive), 36))

    # Candidate tuples: exposure, source, date. Preserve SQL NULL aggregates.
    rx_candidates = []
    for r in get("cohort_variable_union_rx"):
        var = r["variable"]
        if var == "rx_contrast_methotrexate":
            rx_candidates.append(("methotrexate", "rx_order", r["rx_authoredon_date"]))
        if var.startswith("rx_chemo_") or (corrected and var == "rx_contrast_methotrexate"):
            rx_candidates.append(("chemo", "rx_order", r["rx_authoredon_date"]))
    for r in get("llm_systemic_therapy_agent"):
        if r["delivery_status"] != "ADMINISTERED":
            continue
        drug = (r["agent_name"] or "").lower()
        day = field_date(r, "therapy_start_date", corrected)
        is_mtx = ("methotrexate" in drug or "mtx" in drug)
        if is_mtx:
            rx_candidates.append(("methotrexate", "llm_administered", day))
        if not corrected or drug in CHEMO or is_mtx:
            rx_candidates.append(("chemo", "llm_administered", day))
    if corrected:
        for r in e["synthetic_administration"]:
            drug = r["agent_name"]
            day = field_date(r, "administration_date", True)
            if drug == "methotrexate":
                rx_candidates.append(("methotrexate", "llm_administered", day))
            if drug in CHEMO:
                rx_candidates.append(("chemo", "llm_administered", day))
    receipt = [r for r in rx_candidates if r[1] != "rx_order"] if corrected else rx_candidates
    rx = dict(subject_ref=sid, t0_day=t0)
    for drug in ("methotrexate", "chemo"):
        matches = [r for r in receipt if r[0] == drug]
        rx[drug + "_first_day"] = minimum(r[2] for r in matches)
        rx[drug + "_order_first_day"] = minimum(r[2] for r in rx_candidates if r[:2] == (drug, "rx_order"))
        rx[drug + "_administered_first_day"] = minimum(r[2] for r in rx_candidates
                                                       if r[:2] == (drug, "llm_administered"))
        rx[drug + "_any_bool"] = sql_or(r[0] == drug for r in receipt)
    rx["methotrexate_administered_bool"] = sql_or(
        r[:2] == ("methotrexate", "llm_administered") for r in receipt)
    rx["chemo_prior_to_t0_bool"] = (prior_status(
        [r[2] for r in receipt if r[0] == "chemo"], t0, tolerance) if corrected
        else lt(rx["chemo_first_day"], t0))

    rad_candidates = []
    for table, source, key in [
        ("cohort_proc_radiation", "proc", "proc_performed_day"),
        ("cohort_dx_radiation", "dx", "dx_recorded_date")]:
        rad_candidates += [(source, r[key]) for r in get(table) if r["tier"] == 1]
    rounds = get("llm_radiation_wide")
    rad_candidates += [("administered", field_date(r, "radiation_start_date", corrected))
                       for r in rounds if r["delivery_status"] == "ADMINISTERED"]
    # Structured radiotherapy delivery/encounter codes remain candidate evidence.
    fields = [r for r in rounds if r["delivery_status"] == "ADMINISTERED"] if corrected else rounds
    rad = dict(subject_ref=sid, t0_day=t0,
               radiation_first_day=minimum(d for _, d in rad_candidates),
               radiation_any_bool=True if rad_candidates else None,
               radiation_administered_bool=sql_or(s == "administered" for s, _ in rad_candidates),
               llm_craniospinal_bool=sql_or(r["radiation_field"] in
                    {"CRANIOSPINAL", "CRANIOSPINAL_WITH_FOCAL_BOOST"} for r in fields),
               llm_proton_bool=sql_or(r["radiation_method"] == "PROTON" for r in fields),
               llm_explicitly_not_received_bool=sql_or(
                    r["delivery_status"] == "EXPLICITLY_NOT_RECEIVED" for r in rounds))
    for source in ("proc", "dx", "administered"):
        rad["radiation_" + source + "_first_day"] = minimum(d for s, d in rad_candidates if s == source)
    rad["radiation_prior_to_t0_bool"] = (
        prior_status([d for _, d in rad_candidates], t0, tolerance) if corrected
        else lt(rad["radiation_first_day"], t0))

    age = dx["age_months_at_t0"]
    extra = dict(age_band_at_t0=None if age is None else
                 "under_36_months" if age < 36 else "36_months_or_older",
                 age_under_8_months_at_t0=lt(age, 8),
                 atrt_confirmed_bool=bool(dx["atrt_tier1_bool"] or dx["llm_atrt_bool"]))
    if corrected:
        extra["no_prior_chemotherapy_bool"] = negate(rx["chemo_prior_to_t0_bool"])
        extra["no_prior_radiation_bool"] = negate(rad["radiation_prior_to_t0_bool"])
    else:
        extra["no_prior_chemotherapy_bool"] = (False if rx["chemo_prior_to_t0_bool"] else
                                               True if rx["chemo_any_bool"] else None)
        extra["no_prior_radiation_bool"] = (False if rad["radiation_prior_to_t0_bool"] else
            True if rad["radiation_any_bool"] or rad["llm_explicitly_not_received_bool"] else None)
    elig = subset("eligible", dx, surg, rx, rad, extra)

    fhir = e["patient"][0]
    vital_rows = get("llm_survival_timeline_wide")
    events = [r for r in get("llm_event_wide") if r["event_type"] in EFS_TYPES]
    llmdeath = minimum(field_date(r, "death_date", corrected) for r in vital_rows)
    llmalive = maximum(field_date(r, "last_known_alive_date", corrected) for r in vital_rows)
    lastenc = maximum(r["enc_period_end_day_filled"] for r in get("cohort_study_population"))
    deathday = minimum([fhir["deceasedDateTime"], llmdeath] +
        ([field_date(r, "event_date", True) for r in events if r["event_type"] == "DECEASED"]
         if corrected else []))
    dead = bool(fhir["deceasedBoolean"] or deathday or
                any(r["vital_status"] == "DECEASED" for r in vital_rows) or
                (corrected and any(r["event_type"] == "DECEASED" for r in events)))
    alive = maximum([lastenc, llmalive])
    if corrected and deathday is not None and alive is not None:
        alive = min(alive, deathday)
    vital = dict(subject_ref=sid, t0_day=t0, deceased_bool=dead, death_day=deathday,
                 last_known_alive_day=alive, fhir_deceased_bool=fhir["deceasedBoolean"],
                 fhir_death_day=fhir["deceasedDateTime"], last_encounter_day=lastenc,
                 llm_deceased_bool=sql_or(r["vital_status"] == "DECEASED" for r in vital_rows),
                 llm_death_day=llmdeath, llm_last_known_alive_day=llmalive)

    candidates = [(r["event_type"], field_date(r, "event_date", corrected)) for r in events]
    if corrected:
        candidates = [(kind, d) for kind, d in candidates if kind != "DECEASED"]
        if dead:
            candidates.append(("DECEASED", deathday))
        candidates = [(kind, d if t0 is not None and d is not None and d >= t0 else None)
                      for kind, d in candidates]
    elif deathday is not None:
        candidates.append(("DECEASED", deathday))
    unknown = sum(d is None for _, d in candidates)
    followup = maximum(field_date(r, "assessment_date", True)
                       for r in e["synthetic_event_free_follow_up"])
    if corrected and followup is not None:
        followup = minimum([followup, alive, deathday])
        if t0 is None or followup < t0:
            followup = None
    first = minimum(d for _, d in candidates)
    if corrected and unknown:
        first = None
    kinds = ",".join(sorted({k for k, d in candidates if d == first and first is not None})) or None
    anyevent = (bool(candidates) if candidates or followup is not None else None) if corrected else first is not None
    event = dict(subject_ref=sid, t0_day=t0, first_event_day=first, first_event_type=kinds,
                 any_event_bool=anyevent, death_day=deathday,
                 undated_event_cnt=(unknown or None) if corrected else
                    (sum(r["event_date"] is None for r in events) or None),
                 days_t0_to_first_event=duration(t0, first, corrected))
    for kind, col in [("PROGRESSION", "progression_first_day"), ("RECURRENCE", "recurrence_first_day"),
                      ("SECOND_MALIGNANCY", "second_malignancy_first_day")]:
        event[col] = minimum(d for k, d in candidates if k == kind)

    exposure = dict(subject_ref=sid, t0_day=t0, first_event_day=first, first_event_type=kinds)
    for drug in ("methotrexate", "chemo", "radiation"):
        day = elig[drug + "_first_day"]
        exposure[drug + "_first_day"] = day
        if day is None:
            before = None
        elif first is not None:
            before = lt(day, first)
        elif not corrected:
            before = True
        else:
            before = True if anyevent is False and followup is not None and day <= followup else None
        exposure[drug + "_prior_to_first_event_bool"] = before
    c, r = exposure["chemo_prior_to_first_event_bool"], exposure["radiation_prior_to_first_event_bool"]
    if c and r:
        cd, rd = exposure["chemo_first_day"], exposure["radiation_first_day"]
        sequence = "CHEMOTHERAPY_BEFORE_RADIATION" if cd < rd else "RADIATION_BEFORE_CHEMOTHERAPY" if cd > rd else "SAME_DAY"
    else:
        sequence = "CHEMOTHERAPY_ONLY" if c else "RADIATION_ONLY" if r else None
    names = {r["protocol_name_verbatim"] for r in get("llm_systemic_therapy_regimen")} | {
        r["protocol_name"] for r in get("llm_survival_timeline_anchor")}
    exposure.update(initial_therapy_sequence=sequence,
                    protocol_names=" | ".join(sorted(n for n in names if n is not None)) or None)
    osend = deathday if dead else alive
    if corrected and (t0 is None or (osend is not None and osend < t0)):
        osend = None
    efsend = first if anyevent else (followup if corrected else alive)
    if corrected and (anyevent is None or (anyevent and first is None)):
        efsend = None
    if corrected and osend is not None and efsend is not None:
        efsend = min(efsend, osend)
    outcome = subset("outcome", elig, exposure, vital, event, dict(
        os_event_bool=dead, os_end_day=osend, os_days=duration(t0, osend, corrected),
        efs_event_bool=anyevent, efs_end_day=efsend, efs_days=duration(t0, efsend, corrected),
        efs_censor_source=("first_event" if first is not None else
            "unresolved_event_date" if anyevent else
            "event_free_follow_up" if corrected and followup is not None else
            "unknown_follow_up" if corrected else "last_known_alive_provisional")))
    trial = bool((elig["medulloblastoma_tier1_bool"] or elig["llm_medulloblastoma_bool"])
                 and elig["age_under_36_months_at_definitive_surgery"]
                 and not elig["atrt_confirmed_bool"] and elig["no_prior_chemotherapy_bool"]
                 and elig["no_prior_radiation_bool"])
    if corrected:
        prevalent = any(r["event_date"] is not None and t0 is not None
                        and r["event_date"] < t0 for r in events)
        prevalent = prevalent or (deathday is not None and t0 is not None and deathday < t0)
        trial = trial and t0 is not None and not prevalent
    rows = {"eligible_dx": subset("eligible_dx", dx),
            "eligible_surgery": subset("eligible_surgery", surg),
            "eligible_rx": subset("eligible_rx", rx),
            "eligible_radiation": subset("eligible_radiation", rad),
            "eligible": elig, "eligible_trial": dict(elig) if trial else None,
            "outcome_vital_status": subset("outcome_vital_status", vital),
            "outcome_first_event": subset("outcome_first_event", event),
            "outcome_exposure": subset("outcome_exposure", exposure),
            "outcome": outcome}
    return rows


def empty_evidence():
    return {name: [] for name in INPUTS}


def add(e, table, **values):
    unknown = values.keys() - set(INPUTS[table])
    if unknown:
        raise AssertionError((table, unknown))
    e[table].append({key: values.get(key) for key in INPUTS[table]})


def simulate(index, args):
    # Per-patient RNG: increasing N preserves previously generated patients.
    key = f"{VERSION}:{args.seed}:{index}".encode()
    rng = random.Random(int.from_bytes(hashlib.sha256(key).digest(), "big"))
    sid = f"Patient/synthetic-{index:08d}"
    site = rng.randrange(5)
    miss = min(.8, args.missing_rate * (.75 + site * .15))
    e = empty_evidence()
    flags = set()

    def observed(d, *, missing=True, coarse=True, lag=0):
        if d is None:
            return None, None
        if missing and rng.random() < miss:
            flags.add("missing_date")
            return None, None
        shift = round(rng.gauss(0, args.date_jitter_days))
        shift = max(-21, min(21, shift))
        if rng.random() < args.error_rate:
            shift += rng.choice([-1, 1]) * rng.randint(30, 180)
            flags.add("large_date_error")
        value = min(args.as_of, d + (shift + lag) * DAY)
        precision = "DAY"
        if coarse and rng.random() < args.coarse_date_rate:
            precision = weighted(rng, ["MONTH", "YEAR"], [.85, .15])
            value = value.replace(day=1)
            if precision == "YEAR":
                value = value.replace(month=1)
            flags.add("coarse_date")
        return value, precision

    def row(table, **values):
        add(e, table, subject_ref=sid, **values)

    surgery = args.start_date + rng.randrange((args.end_date - args.start_date).days + 1) * DAY
    older = rng.random() < args.older_fraction
    age_days = (rng.randint(36 * 31, 8 * 365) if older else
                round(67 + rng.betavariate(2.0, 1.3) * (1078 - 67)))
    birth = surgery - age_days * DAY
    dxday = surgery - rng.randint(0, 7) * DAY
    enrollment = surgery + rng.randint(7, 21) * DAY
    assigned_mtx = rng.random() < REFERENCE["methotrexate_assignment"]
    actual_atrt = rng.random() < args.atrt_fraction
    subtype = "ATRT" if actual_atrt else weighted(
        rng, ["MEDULLOBLASTOMA", "ETMR", "PINEOBLASTOMA", "OTHER_CNS_EMBRYONAL"],
        [46, 14, 9, 8])
    group = (weighted(rng, ["GROUP_3", "SHH", "GROUP_4", "UNCLASSIFIED"],
                       REFERENCE["MB_molecular_weights"])
             if subtype == "MEDULLOBLASTOMA" else "NOT_APPLICABLE")
    metastatic_p = ({"GROUP_3": .88, "SHH": 6 / 11, "GROUP_4": .75,
                     "UNCLASSIFIED": .55}.get(group) if subtype == "MEDULLOBLASTOMA"
                    else {"ETMR": 3 / 14, "PINEOBLASTOMA": 6 / 9}.get(subtype, .40))
    stage = weighted(rng, ["M1", "M2", "M3"], [3, 12, 28]) if rng.random() < metastatic_p else "M0"
    extent = weighted(rng, ["GROSS_TOTAL_RESECTION", "NEAR_TOTAL_RESECTION", "PARTIAL_RESECTION"],
                      REFERENCE["resection_weights"])
    residual = (0.0 if extent == "GROSS_TOTAL_RESECTION" else
                round(rng.uniform(.1, 1.49) if extent == "NEAR_TOTAL_RESECTION"
                      else rng.uniform(1.51, 8.0), 2))
    # Illustrative joint distribution: nodular histology concentrated in SHH.
    # The article reports marginals, not a complete histology/subgroup cross-tab.
    hist_weights = [3, 7, 1] if group == "SHH" else [26, 0, 9]
    histology = (weighted(rng, ["CLASSIC", "DESMOPLASTIC_NODULAR", "LARGE_CELL_ANAPLASTIC"],
                          hist_weights) if subtype == "MEDULLOBLASTOMA" else "NONE_OF_THE_ABOVE")
    # Preserve subgroup dependence; do not treat trial subgroup estimates as certainty.
    arm = int(assigned_mtx)
    if group == "GROUP_3":
        efs5, os5 = REFERENCE["G3_five_year_EFS"][arm], REFERENCE["G3_five_year_OS"][arm]
    elif group == "SHH":
        efs5, os5 = .95, .97  # Illustrative smoothing of the small zero-event subgroup.
    elif subtype == "MEDULLOBLASTOMA":
        efs5, os5 = REFERENCE["MB_five_year_EFS"][arm], [.60, .78][arm]
    else:
        # Pooled, illustrative non-MB priors; no imposed MTX benefit.
        efs5, os5 = {"ETMR": (.286, .40), "PINEOBLASTOMA": (.12, .20),
                    "OTHER_CNS_EMBRYONAL": (.40, .52), "ATRT": (.40, .55)}[subtype]
    u = rng.random()
    eventday = deathday = None
    eventtype = None
    if u >= efs5:
        # Most failures are early; a small tail allows less trial-like EHR cases.
        upper = 365 if subtype == "ETMR" else 578
        days_to_event = (round(21 + rng.betavariate(1.5, 1.8) * (upper - 21))
                         if rng.random() < .92 else rng.randint(upper + 1, 1700))
        eventday = enrollment + days_to_event * DAY
        eventtype = weighted(rng, ["PROGRESSION", "RECURRENCE"], [.60, .40])
        if u >= os5:
            deathday = eventday + rng.randint(0, max(0, 1826 - days_to_event)) * DAY
            if rng.random() < .05:
                eventtype, eventday = "DECEASED", deathday
    elif rng.random() < .025:
        # Late events are a simulation assumption, not a trial estimate.
        eventday = enrollment + rng.randint(1827, 3652) * DAY
        eventtype = "SECOND_MALIGNANCY"
        if rng.random() < .5:
            deathday = eventday + rng.randint(30, 730) * DAY
    true_first = minimum([eventday, deathday])
    assert deathday is None or true_first is None or true_first <= deathday

    transfer = rng.random() < args.transfer_rate
    local = dxday + (rng.randint(30, 120) if transfer else rng.randint(0, 5)) * DAY
    local = min(local, args.as_of)
    if transfer:
        flags.add("transfer_after_original_diagnosis")
    lastcontact = min(args.as_of, deathday) if deathday else args.as_of
    lost = rng.random() < args.lost_followup_rate
    if lost:
        lastcontact = min(lastcontact, enrollment + rng.randint(20, 1800) * DAY)
        flags.add("lost_follow_up")
    lastcontact = max(surgery, lastcontact)
    gender = "female" if rng.random() < REFERENCE["female"] else "male"
    recorded_birth = None if rng.random() < miss / 4 else birth
    row("core__patient", birthdate=recorded_birth, gender=gender)

    # All N are discovery candidates. True ATRT carries a nonspecific candidate code.
    coded_subtype = subtype.lower() if subtype not in {"ATRT", "OTHER_CNS_EMBRYONAL"} else "cns_embryonal"
    tier = 2 if actual_atrt or rng.random() < miss else 1
    coded_day, _ = observed(local, missing=False, coarse=False)
    row("pcx__cohort_casedef", subtype=coded_subtype, tier=tier, enc_period_start_day=coded_day)
    if tier == 2:
        flags.add("no_tier1_MB_anchor")
    if actual_atrt:
        row("pcx__cohort_casedef", subtype="atrt", tier=1, enc_period_start_day=coded_day)
    if rng.random() > miss:
        for _ in range(rng.randint(1, 3)):
            dd, dp = observed(dxday)
            gd, gp = observed(surgery)
            reported_subtype = subtype
            if rng.random() < args.error_rate:
                reported_subtype = "ATRT" if subtype == "MEDULLOBLASTOMA" else "MEDULLOBLASTOMA"
                flags.add("conflicting_diagnosis")
            row("pcx__llm_diagnosis_wide", disease_subtype=reported_subtype,
                medulloblastoma_histology=histology, chang_m_stage=stage,
                diagnosis_date=dd, diagnosis_date_precision=dp,
                diagnosis_date_gold=gd, diagnosis_date_gold_precision=gp,
                age_at_diagnosis_months=None if rng.random() < miss else months(birth, dxday))

    if not transfer or rng.random() < .25:
        sd, _ = observed(surgery, coarse=False)
        row("pcx__cohort_proc_craniotomy", procedure_ref=f"Procedure/synthetic-{index}-1",
            tier=1, proc_performed_day=sd)
    if rng.random() > miss:
        sd, sp = observed(surgery)
        row("pcx__llm_surgery_wide", surgery_date=sd, surgery_date_precision=sp,
            extent_of_resection=extent, age_at_surgery_months=months(birth, surgery),
            residual_tumor_area_cm2=residual if rng.random() > miss else None)
    if residual > 0 and rng.random() < .12 and surgery + 70 * DAY < lastcontact:
        sd, sp = observed(surgery + rng.randint(60, 90) * DAY)
        row("pcx__llm_surgery_wide", surgery_date=sd, surgery_date_precision=sp,
            extent_of_resection="GROSS_TOTAL_RESECTION", age_at_surgery_months=None,
            residual_tumor_area_cm2=0.0)

    # Treatment chronology, with cycle delays and early discontinuation.
    cycle_dates = [enrollment]
    for interval in (21, 21, 28, 28, 28):
        cycle_dates.append(cycle_dates[-1] + (interval + rng.randint(0, 12)) * DAY)
    stop = minimum([eventday, deathday, args.as_of])
    cycles = [d for d in cycle_dates if d <= args.as_of and (stop is None or d < stop)]
    treatment_by_drug = {}
    if rng.random() <= .03:  # Illustrative nonreceipt/refusal case.
        cycles = []
    if cycles:
        for j, cycle in enumerate(cycles):
            drugs = (["cisplatin", "vincristine", "etoposide", "cyclophosphamide"] +
                     (["methotrexate"] if assigned_mtx else [])) if j < 3 else ["carboplatin", "thiotepa"]
            for drug in drugs:
                treatment_by_drug.setdefault(drug, cycle)
    for drug, actual in treatment_by_drug.items():
        if actual > lastcontact and not transfer:
            continue
        if rng.random() > miss:
            od, _ = observed(actual, coarse=False, lag=-rng.randint(0, 5))
            variable = "rx_contrast_methotrexate" if drug == "methotrexate" else "rx_chemo_" + drug
            row("pcx__cohort_variable_union_rx", variable=variable, rx_authoredon_date=od)
        dose_only = rng.random() < .10
        if rng.random() > miss:
            ad, ap = observed(actual)
            row("pcx__llm_systemic_therapy_agent", agent_name=drug,
                delivery_status="NONE_OF_THE_ABOVE" if dose_only else "ADMINISTERED",
                therapy_start_date=None if dose_only else ad,
                therapy_start_date_precision=None if dose_only else ap)
        if rng.random() > miss:
            ad, ap = observed(actual)
            row("synthetic_administration", agent_name=drug,
                administration_date=ad, administration_date_precision=ap)
        if dose_only:
            flags.add("administration_only_evidence")
    if not assigned_mtx and rng.random() < args.error_rate * 2:
        od, _ = observed(enrollment, coarse=False)
        row("pcx__cohort_variable_union_rx", variable="rx_contrast_methotrexate", rx_authoredon_date=od)
        flags.add("methotrexate_order_without_receipt")
    protocol = "ACNS0333" if actual_atrt else weighted(
        rng, ["ACNS0334", "Head Start", "CCG99703", None], [.65, .20, .10, .05])
    if protocol and rng.random() > miss:
        row("pcx__llm_systemic_therapy_regimen", protocol_name_verbatim=protocol)
    if protocol and rng.random() > miss:
        row("pcx__llm_survival_timeline_anchor", protocol_name=protocol)

    # Radiation is correlated with relapse and residual disease, not mandatory.
    rad_day = None
    if eventday and eventtype != "DECEASED" and eventday <= lastcontact and rng.random() < .55:
        rad_day = eventday + rng.randint(10, 60) * DAY
    elif subtype != "ETMR" and residual > 0 and rng.random() < (.09 if group == "SHH" else .20):
        rad_day = enrollment + rng.randint(160, 240) * DAY
    if rad_day and (rad_day > lastcontact or (deathday and rad_day >= deathday)):
        rad_day = None
    field = "CRANIOSPINAL" if stage != "M0" else "FOCAL_TUMOR_BED"
    method = "PROTON" if rng.random() < .35 else "PHOTON"
    if rad_day:
        for table, key in [("pcx__cohort_proc_radiation", "proc_performed_day"),
                           ("pcx__cohort_dx_radiation", "dx_recorded_date")]:
            if rng.random() > miss:
                rd, _ = observed(rad_day, coarse=False)
                row(table, tier=1, **{key: rd})
        if rng.random() > miss:
            rd, rp = observed(rad_day)
            row("pcx__llm_radiation_wide", delivery_status="ADMINISTERED",
                radiation_start_date=rd, radiation_start_date_precision=rp,
                radiation_field=field, radiation_method=method)
    elif rng.random() > .30:
        planned = rng.random() < .12
        rd, rp = observed(enrollment + 180 * DAY) if planned else (None, None)
        row("pcx__llm_radiation_wide", delivery_status="PLANNED" if planned else "EXPLICITLY_NOT_RECEIVED",
            radiation_start_date=rd, radiation_start_date_precision=rp,
            radiation_field=field if planned else "NONE_OF_THE_ABOVE",
            radiation_method=method if planned else "NONE_OF_THE_ABOVE")
        if planned:
            flags.add("planned_radiation_only")

    # Contacts can be shorter than a year; never impose a survivor-only filter.
    contacts = [surgery]
    contacts += [d for d in cycles if d <= lastcontact]
    d = enrollment + 180 * DAY
    while d <= lastcontact:
        if rng.random() > miss:
            contacts.append(d)
        elapsed = (d - enrollment).days
        d += (90 if elapsed < 365 else 120 if elapsed < 730 else 180 if elapsed < 1095 else 365) * DAY
    contacts.append(lastcontact)
    for d in sorted(set(contacts)):
        od, _ = observed(d, missing=False, coarse=False)
        row("pcx__cohort_study_population", enc_period_end_day_filled=od)

    # An event need not be captured by every source or at exact precision.
    event_seen = eventday is not None and eventday <= lastcontact
    if event_seen and rng.random() > miss:
        ed, ep = observed(eventday)
        row("pcx__llm_event_wide", event_type=eventtype, event_date=ed, event_date_precision=ep)
    death_seen = deathday is not None and deathday <= args.as_of
    death_source = weighted(rng, ["both", "fhir", "llm", "event", "missing"],
                             [.45, .20, .20, .10, .05]) if death_seen else "alive"
    fd = None
    fb = False if not death_seen else None
    if death_source in {"both", "fhir"}:
        fb = True
        fd, _ = observed(deathday, coarse=False)
    add(e, "patient", id=sid.split("/")[1], deceasedBoolean=fb, deceasedDateTime=fd)
    if death_source == "event":
        ed, ep = observed(deathday)
        row("pcx__llm_event_wide", event_type="DECEASED", event_date=ed, event_date_precision=ep)
        flags.add("event_only_death")
    if rng.random() > miss:
        dd, dp = observed(deathday) if death_source in {"both", "llm"} else (None, None)
        ld, lp = observed(lastcontact)
        row("pcx__llm_survival_timeline_wide",
            vital_status="DECEASED" if death_source in {"both", "llm"} else "ALIVE",
            death_date=dd, death_date_precision=dp,
            last_known_alive_date=ld, last_known_alive_date_precision=lp)
    ef_days = [d for d in contacts if (true_first is None or d < true_first) and d >= enrollment]
    if ef_days and rng.random() > miss:
        ed, ep = observed(max(ef_days))
        row("synthetic_event_free_follow_up", assessment_date=ed, assessment_date_precision=ep)
    truth = dict(subject_ref=sid, site=f"synthetic-site-{site + 1}", birthdate=birth,
                 disease_subtype=subtype, molecular_group=group, chang_m_stage=stage,
                 histology=histology, extent_of_resection=extent, residual_area_cm2=residual,
                 diagnosis_day=dxday, definitive_surgery_day=surgery, latent_enrollment_day=enrollment,
                 age_months_at_surgery=months(birth, surgery), assigned_methotrexate=assigned_mtx,
                 first_methotrexate_day=treatment_by_drug.get("methotrexate"),
                 first_chemotherapy_day=minimum(treatment_by_drug.values()),
                 radiation_day=rad_day, latent_first_event_day=true_first,
                 latent_event_type=eventtype, latent_death_day=deathday,
                 last_contact_day=lastcontact, death_by_as_of=death_seen,
                 simulated_cycles_started=len(cycles), transfer=transfer,
                 lost_follow_up=lost, noise_flags="|".join(sorted(flags)))
    return e, truth


def encode(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, date):
        return value.isoformat()
    return str(value)


def check_rows(rows, corrected):
    sid = rows["eligible"]["subject_ref"]
    for table in TABLE_ORDER:
        row = rows[table]
        if row is None:
            assert table == "eligible_trial"
            continue
        assert list(row) == SCHEMAS[table], table
        assert row["subject_ref"] == sid
    if corrected:
        o = rows["outcome"]
        for key in ("os_days", "efs_days"):
            assert o[key] is None or o[key] >= 0, (sid, key)
        if o["os_end_day"] is not None and o["efs_end_day"] is not None:
            assert o["efs_end_day"] <= o["os_end_day"]
        if rows["eligible_trial"] is not None:
            assert rows["eligible"]["t0_day"] is not None


def column_type(name):
    if "bool" in name or name.startswith("age_under_"):
        return "BOOLEAN"
    if name == "birthdate" or name.endswith("_day") or "_day_" in name:
        return "DATE"
    if "residual_tumor_area" in name or name == "llm_age_at_definitive_surgery_months":
        return "DOUBLE"
    if "months" in name or name.endswith("_cnt") or name in {"os_days", "efs_days", "days_t0_to_first_event"}:
        return "BIGINT"
    return "VARCHAR"


def parser():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--patients", "-n", type=int, required=True)
    p.add_argument("--output", "-o", type=Path, required=True)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--start-date", type=date.fromisoformat, default=date(2008, 1, 1))
    p.add_argument("--end-date", type=date.fromisoformat, default=date(2021, 12, 31))
    p.add_argument("--as-of", type=date.fromisoformat, default=date(2026, 9, 17))
    p.add_argument("--missing-rate", type=float, default=.12)
    p.add_argument("--date-jitter-days", type=float, default=2.0,
                   help="SD of ordinary signed EHR date error; default 2 days.")
    p.add_argument("--coarse-date-rate", type=float, default=.06)
    p.add_argument("--error-rate", type=float, default=.02,
                   help="Probability of rare large date errors/diagnosis conflicts.")
    p.add_argument("--older-fraction", type=float, default=.18)
    p.add_argument("--atrt-fraction", type=float, default=.06)
    p.add_argument("--transfer-rate", type=float, default=.12)
    p.add_argument("--lost-followup-rate", type=float, default=.15)
    p.add_argument("--date-tolerance-days", type=int, default=3,
                   help="Corrected baseline ordering is unknown within +/- this many days.")
    p.add_argument("--inputs", action="store_true",
                   help="Also emit minimal shared upstream CSVs for reproducible SQL tests.")
    return p


def validate_args(p, a):
    if a.patients < 0:
        p.error("--patients must be nonnegative")
    if not (date(1900, 1, 1) <= a.start_date <= a.end_date <= a.as_of <= date(2090, 1, 1)):
        p.error("Require 1900-01-01 <= start-date <= end-date <= as-of <= 2090-01-01")
    for name in ("missing_rate", "coarse_date_rate", "error_rate", "older_fraction",
                 "atrt_fraction", "transfer_rate", "lost_followup_rate"):
        if not math.isfinite(getattr(a, name)) or not 0 <= getattr(a, name) <= 1:
            p.error("--" + name.replace("_", "-") + " must be between 0 and 1")
    if not math.isfinite(a.date_jitter_days) or not 0 <= a.date_jitter_days <= 30:
        p.error("--date-jitter-days must be between 0 and 30")
    if not 0 <= a.date_tolerance_days <= 30:
        p.error("--date-tolerance-days must be between 0 and 30")


def main(argv=None):
    p = parser()
    a = p.parse_args(argv)
    validate_args(p, a)
    output = a.output.expanduser()
    if output.exists():
        p.error(f"Output already exists; choose a new directory: {output}")
    # Exclusive creation prevents silently overwriting existing test datasets.
    output.mkdir(parents=True, exist_ok=False)
    handles = []
    counts = Counter({"truth": 0})
    for mode in ("current_sql", "corrected"):
        for table in TABLE_ORDER:
            counts[mode + "/" + PREFIX + table] = 0
    if a.inputs:
        counts.update({"inputs/" + table: 0 for table in INPUTS})
    differences = Counter()
    summary = {mode: Counter() for mode in ("current_sql", "corrected")}

    def writer(relative, columns):
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        handle = target.open("w", encoding="utf-8", newline="")
        handles.append(handle)
        w = csv.writer(handle, lineterminator="\n")
        w.writerow(columns)
        return w

    try:
        writers = {(mode, table): writer(f"{mode}/{PREFIX}{table}.csv", SCHEMAS[table])
                   for mode in ("current_sql", "corrected") for table in TABLE_ORDER}
        input_writers = {table: writer(f"inputs/{table}.csv", cols)
                         for table, cols in INPUTS.items()} if a.inputs else {}
        diffwriter = writer("differences.csv", ["subject_ref", "table", "column", "current_sql", "corrected"])
        truthwriter = None
        truth_columns = []
        # Obtain truth headers without depending on N being nonzero.
        _, example_truth = simulate(0, a)
        truth_columns = list(example_truth)
        truthwriter = writer("truth.csv", truth_columns)
        for i in range(1, a.patients + 1):
            evidence, truth = simulate(i, a)
            truthwriter.writerow(encode(truth[k]) for k in truth_columns)
            counts["truth"] += 1
            if a.inputs:
                for table, rows in evidence.items():
                    for row in rows:
                        input_writers[table].writerow(encode(row[k]) for k in INPUTS[table])
                        counts["inputs/" + table] += 1
            paired = {}
            for mode in ("current_sql", "corrected"):
                rows = derive(evidence, mode == "corrected", a.date_tolerance_days)
                check_rows(rows, mode == "corrected")
                paired[mode] = rows
                for table, row in rows.items():
                    if row is not None:
                        writers[mode, table].writerow(encode(row[k]) for k in SCHEMAS[table])
                        counts[mode + "/" + PREFIX + table] += 1
                o = rows["outcome"]
                summary[mode]["patients"] += 1
                summary[mode]["trial_patients"] += rows["eligible_trial"] is not None
                summary[mode]["known_deaths"] += o["os_event_bool"] is True
                summary[mode]["missing_t0"] += o["t0_day"] is None
                summary[mode]["negative_os"] += o["os_days"] is not None and o["os_days"] < 0
                summary[mode]["negative_efs"] += o["efs_days"] is not None and o["efs_days"] < 0
            for table in TABLE_ORDER:
                before, after = paired["current_sql"][table], paired["corrected"][table]
                if (before is None) != (after is None):
                    diffwriter.writerow([truth["subject_ref"], PREFIX + table, "__row_present__",
                                         encode(before is not None), encode(after is not None)])
                    differences[table + ".__row_present__"] += 1
                elif before is not None:
                    for key in SCHEMAS[table]:
                        if before[key] != after[key]:
                            diffwriter.writerow([truth["subject_ref"], PREFIX + table, key,
                                                 encode(before[key]), encode(after[key])])
                            differences[table + "." + key] += 1
        for mode in ("current_sql", "corrected"):
            for table in TABLE_ORDER:
                expected = a.patients if table != "eligible_trial" else summary[mode]["trial_patients"]
                assert counts[mode + "/" + PREFIX + table] == expected
    finally:
        for handle in handles:
            handle.close()

    config = {k: str(v) if isinstance(v, (date, Path)) else v for k, v in vars(a).items()}
    manifest = dict(version=VERSION, complete=True, configuration=config,
                    reference=REFERENCE, policies=POLICIES,
                    csv_contract=dict(null="", boolean=["true", "false"], date="YYYY-MM-DD"),
                    schemas={PREFIX + t: {c: column_type(c) for c in SCHEMAS[t]} for t in TABLE_ORDER},
                    row_counts=dict(sorted(counts.items())),
                    summary={k: dict(v) for k, v in summary.items()},
                    differences=dict(sorted(differences.items())))
    # Written last: absence of manifest.json means an interrupted/incomplete run.
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output.resolve()), "summary": manifest["summary"]}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
