# Protocol: pcx

The single record of what this study is and why. Every skill reads its section first and
writes decisions back. Tags on every line: `[source <doc>]` from a starting document,
`[decided]` by the researcher, `[assumed]` by the agent and awaiting review, `[open]`
unanswered. The numbered headings are the contract the skills and `cumulus-study validate`
depend on: keep the numbers and their order, add subsections freely.

Inherited source documents are in `docs/source/`; "workplan N.N" below cites the inherited
`docs/source/workplan.md` (2026-09-11). Migration mechanics are in [MIGRATION.md](MIGRATION.md);
open work is in [WORKPLAN.md](WORKPLAN.md). Paths name today's `study/` package, which becomes
`cumulus_library_pcx/` with builder 0.5.0. Other sites run the study from a clone of this
repository with `cumulus-library build --study-dir cumulus_library_pcx`; it is not pip-installed.

## 0. Source

- [source README] Retrospective, proof-of-concept EHR emulation of clinical trial ACNS0334
  (NCT00336024; Mazewski, Leary et al., PMC12833527): high-dose methotrexate added to an intensive
  chemotherapy backbone for young children with medulloblastoma and other embryonal brain tumors.
- [decided] Migrated 2026-09-19 from `cumulus-library-pcx` (read-only); file hashes in
  `docs/source_inventory.json`. Inherited design notes: `docs/source/{README,eligible,limitations,
  workplan,llm,laboratory,deferred}.md` as of 2026-09-11.

## 1. Objective

- [source limitations] Objective: assess whether the treatment-associated outcome differences seen
  in ACNS0334 are also seen in comparable EHR-derived medulloblastoma cohorts, prioritizing
  molecular Group 3. An observational treatment-effect analysis is not yet specified.
- [source eligible] Design: a discovery cohort (`pcx__eligible`, every criterion as a nullable
  boolean) and a trial-like cohort (`pcx__eligible_trial`, strict intersection).
- [source eligible] Analysis unit: subject; time zero is the first study-population encounter with
  a tier 1 medulloblastoma code.
- [decided] Prefix `pcx`. Stages in `study/stage/manifest.py`: fhir_resource, study_population,
  study_variable, study_variable_wide, casedef, sample, llm_schema, counts, study_meta by default;
  elastic_upload, the four NLP workflows, llm_document_wide, llm_clinical_wide, eligible, outcome,
  client_views, qa_athena opt-in. A demonstration biostats stage is present but commented out.
- [decided] Data package version 2.

## 2. Population

- [source eligible] Encounters from 2008-01-01 with prior history; ages 0-8 at the visit;
  all genders; 2 or more distinct encounter periods spanning 365 or more days; laboratory
  Observations; all DiagnosticReport categories. Files: `spreadsheet/include_*.csv`.
- [decided] Age groups: Infant (0), Early childhood (1-4), Childhood (5-8) in `age_group.csv`.
- [source limitations] The utilization filter is a follow-up filter, not censoring; it can remove
  early deaths. Survival analyses should not inherit it without a selection design (workplan 2.7).

## 3. Variables

One CSV per concept in `spreadsheet/`; see [spreadsheet/README.md](spreadsheet/README.md).

- [source] Diagnoses: `dx_medulloblastoma`, `dx_atrt`, `dx_brain_cancer`, `dx_radiation`,
  `dx_methotrexate_toxic` (discovery only; the eligible SQL reads casedef, not these files).
- [source] Chemotherapy orders: `rx_chemo_{carboplatin,cisplatin,cyclophosphamide,etoposide,
  thiotepa,vincristine}`; causal contrast `rx_contrast_methotrexate` (86 codes).
- [source] Procedures: `proc_craniotomy`, `proc_radiation` (candidate codes, marked verify).
- [source laboratory] Toxicity laboratories: `lab_{absolute_neutrophil_count,alt,ast,creatinine,
  hemoglobin,platelets,total_bilirubin}`; no eligible or outcome SQL reads a lab table yet.
- [open] Creatinine has one LOINC; hemoglobin still includes local reticulocyte code 923;
  methotrexate serum levels and leucovorin have no valueset (limitations.md).

## 4. Case definition

- [source] `spreadsheet/casedef.csv`: 55 rows, subtypes medulloblastoma, atrt, cns_embryonal,
  etmr, pineoblastoma; tiers 1-2. Tier 1 medulloblastoma sets time zero; tier 2 codes are evidence.
- [source eligible] Index event: first study-population encounter carrying a tier 1
  medulloblastoma code (`pcx__eligible_dx.sql`). `pcx__cohort_casedef` keeps a second anchor
  (first casedef encounter of any subtype or tier) for note sampling (workplan 2.6).
- [open] SNOMED 428061005 is tier 1 ATRT in casedef.csv but "Malignant tumor of brain" in
  dx_brain_cancer.csv (workplan 2.3). ICD-O-3 morphology codes are absent from casedef.csv
  (workplan 2.4); etmr, pineoblastoma and cns_embryonal never produce a time zero (workplan 2.5).

## 5. Clinical notes

- [source llm] 14 extraction models in `study/llm/models/`: diagnosis, document_topic,
  document_type, event, laboratory, metastasis, molecular, radiation, registry_eligibility,
  response, surgery, survival_timeline, systemic_therapy, transition_of_care (`treatment.py`
  is shared context, not a task). Workflows: `nlp_document_tasks`, `nlp_clinical_tasks` and their `_50k` variants; 23 wide and
  projection templates in `study/sql/template/`. Deployment `gpt_oss_120b` (`cumulus-study.toml`).
- [decided] Sample windows from the shared sampler: pre, peri, post around the casedef anchor;
  10 patients and 50 notes per window (`cumulus-study.toml`).
- [open] Note selectors: every workflow references `pcx__llm_document_task_<task>` tables that the
  source study never created (`study/nlp-selection-requirements.json`). Supply reviewed selectors
  before running NLP. The 14 tables are declared as site-supplied under `[builder] external_tables`,
  and each workflow's selector guard (`pcx__qa_selector_<workflow>`) stops the stage when a
  selector is missing or empty, since cumulus-library 6.3.1 would otherwise send every note to
  the LLM.
- [open] Full diagnosis workflow is version 2, the limited workflow version 3; the projections
  consume version 2. Decide the version before production. `HOME_INSTITUTION` is site-specific.

## 6. Eligibility

From `docs/source/eligible.md`; SQL in `study/sql/custom/eligible/`, opt-in stage `eligible`.
Every criterion is a nullable boolean: TRUE met, FALSE not met, NULL not evaluable.

- [source] Time zero `t0_day`: first tier 1 medulloblastoma casedef encounter (section 4).
- [source] I1 Diagnosis: tier 1 medulloblastoma casedef code OR an LLM diagnosis of
  MEDULLOBLASTOMA (`pcx__llm_diagnosis_wide`).
- [source] I2 Definitive surgery under 36 months of age: earliest LLM resection (gross total,
  near total, partial) else first tier 1 craniotomy procedure; required in the trial view.
- [source] E1 ATRT: tier 1 atrt casedef code or any single LLM note with subtype ATRT.
- [source] E2 Prior chemotherapy before t0: earliest chemotherapy order or LLM-administered agent.
- [source] E3 Prior radiation before t0: earliest tier 1 radiation procedure, tier 1 radiation
  encounter code, or LLM-administered radiation; `EXPLICITLY_NOT_RECEIVED` sets no-prior TRUE.
- [source] Not computable: organ-function laboratories, staging and residual disease as criteria
  (reported, not applied); sPNET arm never enters the trial view.
- [open] Workplan 2.1-2.2: when any chemotherapy or radiation evidence exists, a NULL time zero
  or an undated LLM record makes the no-prior flag TRUE (`eligible.sql`); with no evidence it is
  NULL, so the trial view requires positive therapy evidence rather than a documented absence.
  ACNS0334 arms give no radiation (NCT00336024), so a child never irradiated leaves the trial
  view unless a note says radiation was not received. "No prior" needs an observation policy.
- [open] Workplan 1.7-1.8: month arithmetic, `varchar = integer` and `DATE(varchar)` behave
  differently on DuckDB and Athena.

## 7. Outcomes

SQL in `study/sql/custom/outcome/`, opt-in stage `outcome`.

- [source limitations] Vital status (`outcome_vital_status.sql`): raw `patient.deceasedBoolean` /
  `deceasedDateTime`, the last study-population encounter, and LLM vital-status mentions; the
  earliest death and latest alive dates win without cross-checking.
- [source limitations] First event (`outcome_first_event.sql`) supports a provisional EFS; a death
  recorded only by the event task reaches EFS but not OS. Coarse LLM dates are consumed as exact days.
- [source] Exposure timing (`outcome_exposure.sql`): first methotrexate and chemotherapy days by
  source. Structured exposure is orders, not administration; LLM ADMINISTERED mentions are the
  only receipt evidence, and every administered agent counts as chemotherapy (workplan 3.4).

## 8. Analysis

### 8.1 Counts

- [source study/cubes.json] 17 count tables covering the study population, coded
  variables and case-definition cohort; names, sources and dimensions unchanged since
  the migration. Each table's description states its population and counted unit.
- [decided] 2026-09-22: defined in `counts.workflow`, built and exported by the shared
  `counts` stage (counts skill), replacing `study/stage/cube.py` and `study/cubes.json`. The
  file is in `study/sql/custom/counts/` today and moves to the package root next to
  `manifest.toml` on 0.5.0. All tables are shared (`export:counts`); no site-only file.
- [decided] Every table counts distinct patients (`subject_ref`) with the builder floor
  of 10. The encounter, DocumentReference and DiagnosticReport tables count the resource
  through `secondary_id`: a cell needs 10 patients and 10 resources, and `cnt` is the
  resource count. Rows with a null patient or resource ID are excluded first.
- [decided] `cube_patient_variable_union` takes `age_group` from the linked
  study-population encounter (join on `encounter_ref_link`); evidence without a linked
  encounter is not counted, as before. `cube_patient_casedef` reads age group and gender
  from `cohort_casedef` itself; the former `_source` join tables are gone.
- [open] Output column order changed for `cube_patient_variable_union` (`age_group` is now
  last); the values and names are the same. Counts have not been run in the warehouse.

### 8.2 Exports and statistical plan

- [decided] Scope: exports only. The opt-in `client_views` stage produces the flat client tables
  (`study/sql/custom/client_views/`, dictionary `spreadsheet/client_dictionary.csv`); no new
  estimand was introduced by the migration.
- [assumed] The biostats scaffold copied from the 0.4 starter (`analysis/exports.toml`,
  `study/stage/biostats.py`, `study/sql/custom/biostats/analysis.sql`) is a demonstration only
  and its stage is commented out; it is removed in the 0.5.0 move. `spreadsheet/data_dictionary.csv`
  is Cumulus Library's column dictionary (`study/manifest.toml`); the builder's biostats
  contract would be `spreadsheet/biostats_dictionary.csv`.
- [open] No treatment-effect analysis, estimand, covariate set or censoring rule is specified.

## 9. Open questions

- [open] Prior-therapy observation policy (section 6) and the diagnosis task version (section 5).
- [open] The original note-selection inputs (query-topic TSVs and `reviews/`) were not migrated.
- [open] Inherited workplan 1.7, 1.8, 2.1-2.7, 3.4, 3.5 (sections 3-7): keep, schedule or close.
- [open] Review 2026-09-19, tracked in WORKPLAN.md: the `_50k` stages run after client_views;
  encounter-only joins in `client_timeline.sql`; notes with conflicting dates have a NULL
  `note_author_date` and drop out of `client_diagnosis.sql`. The builder `cohort_casedef`
  duplicate `subject_ref` defect was not re-checked against 0.5.0.

## 10. Decision log

- [source migration record] 2026-09-19, Andy: migrate the existing study onto
  cumulus-study-builder 0.4.0; source repository read-only; generate and test locally only, no
  warehouse, NLP or patient exports.
- [source migration record] 2026-09-19, migration: document projection precedes the clinical
  workflow; `_50k` workflows opt-in; `HOME_INSTITUTION` resolves from local model settings;
  laboratory `result` alias renamed; data package version 1 -> 2.
- [source migration record] 2026-09-21, Andy: re-align with the current builder and its starter
  (rebuilt 0.4.0 wheel); keep `==0.4.0` pins; add the biostats scaffold as a commented opt-in
  stage; adopt the numbered protocol sections; keep review findings unapplied. See CHANGELOG.md.
- [decided] 2026-09-22, Andy (implemented by agent): align this protocol with the study-builder
  protocol conventions: Objective, Clinical notes, and Analysis with separate Counts and Exports
  and statistical plan subsections.
- 2026-09-24 [decided] Docs target cumulus-study-builder 0.5.0 (starter in the builder, flat
  cumulus_library_pcx/ package, biostats naming, counts workflow at the package root); the code
  move is tracked in WORKPLAN.md. Andy.
- 2026-09-24 [decided] The builder's biostats module is not used outside IBD yet: the demo biostats scaffold is removed in the 0.5.0 move, not converted. Andy.

## Agent rules

_Study-specific instructions for coding agents working in this repository (unnumbered;
not checked by `cumulus-study validate`)._
