# Protocol: pcx

The single record of what this study is and why. Every skill reads its section first and
writes decisions back. Tags on every line: `[source <doc>]` from a starting document,
`[decided]` by the researcher, `[assumed]` by the agent and awaiting review, `[open]`
unanswered. The numbered headings are the contract the skills and `cumulus-study validate`
depend on: keep the numbers and their order, add subsections freely.

Inherited source documents are in `docs/source/`; "workplan N.N" below cites the inherited
`docs/source/workplan.md` (2026-09-11). Migration mechanics are in [MIGRATION.md](MIGRATION.md);
open work is in [WORKPLAN.md](WORKPLAN.md). The study package is `cumulus_library_pcx/`
(builder 0.5.5). Other sites run the study from a clone of this repository with
`cumulus-library build --study-dir cumulus_library_pcx`. From 0.3.0, the eight default stages
without NLP also ship as the data-only PyPI package `cumulus-library-pcx`
(`release/make_data_release.py`).

## 0. Source

- [source README] Retrospective, proof-of-concept EHR emulation of clinical trial ACNS0334
  (NCT00336024; Mazewski, Leary et al., PMC12833527): high-dose methotrexate added to an intensive
  chemotherapy backbone for young children with medulloblastoma and other embryonal brain tumors.
- [decided] Migrated 2026-09-19 from `cumulus-library-pcx` (read-only); the source is
  git tag `0.2-pre-study-builder`. Inherited design notes: `docs/source/{README-0.2,eligible,limitations,
  workplan,llm,laboratory,deferred}.md` as of 2026-09-11.

## 1. Objective

- [source limitations] Objective: assess whether the treatment-associated outcome differences seen
  in ACNS0334 are also seen in comparable EHR-derived medulloblastoma cohorts, prioritizing
  molecular Group 3. An observational treatment-effect analysis is not yet specified.
- [source eligible] Design: a discovery cohort (`pcx__eligible`, every criterion as a nullable
  boolean) and a trial-like cohort (`pcx__eligible_trial`, strict intersection).
- [source eligible] Analysis unit: subject; time zero is the first study-population encounter with
  a tier 1 medulloblastoma code.
- [decided] Prefix `pcx`. Stages in `cumulus_library_pcx/stage/manifest.py`: study_population,
  study_variable, study_variable_wide, casedef, elastic_upload, sample, counts, study_meta by
  default; llm_schema, the four NLP workflows, llm_document_wide, llm_clinical_wide, eligible,
  outcome, client_views, qa_athena opt-in. Medication tables come from Cumulus Library core
  (`core__medicationrequest`, `core__medicationdispense`); there is no `fhir_resource` stage.
- [decided] Data package version 2.

## 2. Population

- [source eligible] Encounters from 2008-01-01 with prior history; all genders; 2 or more
  distinct encounter periods spanning 365 or more days; laboratory Observations; all
  DiagnosticReport categories. Files: `spreadsheet/include_*.csv`.
- [decided] 2026-09-30, Andy: ages 0-120 at the visit (was 0-8), so the population has no
  upper age limit. Age is an eligibility flag (section 6), not a population filter.
- [decided] Age groups in `age_group.csv`: Infant (0), Early childhood (1-4), Childhood (5-11),
  Adolescent (12-17), Young adult (18-25), Adult (26-64), Older adult (65-120).
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

- [source llm] 14 extraction models in `cumulus_library_pcx/llm/models/`: diagnosis, document_topic,
  document_type, event, laboratory, metastasis, molecular, radiation, registry_eligibility,
  response, surgery, survival_timeline, systemic_therapy, transition_of_care (`treatment.py`
  is shared context, not a task). Workflows: `nlp_document_tasks` and `nlp_clinical_tasks`; 23 wide and
  projection templates in `cumulus_library_pcx/sql/template/`. Deployment `gpt_oss_120b` (`cumulus-study.toml`).
- [decided] Sample windows from the shared sampler: pre, peri, post around the casedef anchor;
  10 patients and 50 notes per window (`cumulus-study.toml`).
- [decided] 2026-10-08, Andy: the document tasks (`document_topic`, `document_type`) select every
  note in `pcx__sample_task`, the casedef notes plus the Elasticsearch notes, which the `sample`
  stage builds at every site.
- [open] Note selectors: the clinical workflow references `pcx__llm_document_task_<task>` tables that the
  source study never created. Supply reviewed selectors, each with a `note_ref` column,
  before running it. The 12 tables are declared as site-supplied under `[builder] external_tables`.
  Nothing stops the stage when a selector is empty (no selector guard since builder 0.5.5), and
  cumulus-library 6.3.4 then sends every note to the LLM: check each selector has rows first.
- [open] The diagnosis task is version 2 and the projections consume version 2. The removed
  `_50k` workflow ran it as version 3. Confirm the version before production.
  `HOME_INSTITUTION` is site-specific.

## 6. Eligibility

From `docs/source/eligible.md`; SQL in `cumulus_library_pcx/sql/custom/eligible/`, opt-in stage `eligible`.
`pcx__eligible` is the discovery cohort: every criterion is a yes/no flag, never an exclusion.
`pcx__eligible_trial` applies the strict ACNS0334 intersection on top of it.

- [source] Time zero `t0_day`: first tier 1 medulloblastoma casedef encounter (section 4).
- [source] I1 Diagnosis: tier 1 medulloblastoma casedef code OR an LLM diagnosis of
  MEDULLOBLASTOMA (`pcx__llm_diagnosis_wide`).
- [source] I2 Definitive surgery under 36 months of age: earliest LLM resection (gross total,
  near total, partial) else first tier 1 craniotomy procedure; required in the trial view.
- [decided] 2026-09-30, Andy: age is two flags, `age_under_36_months_at_t0` and
  `age_under_36_months_at_definitive_surgery` (NULL without a date or birthdate). Only the
  surgery flag is a trial criterion.
- [source] E1 ATRT: tier 1 atrt casedef code or any single LLM note with subtype ATRT.
- [source] E2 Prior chemotherapy before t0: earliest chemotherapy order, pharmacy dispense or
  LLM-administered agent.
- [source] E3 Prior radiation before t0: earliest tier 1 radiation procedure, tier 1 radiation
  encounter code, or LLM-administered radiation.
- [decided] 2026-09-30, Andy: prior therapy is three flags, `methotrexate_prior_to_t0_bool`,
  `chemo_prior_to_t0_bool` and `radiation_prior_to_t0_bool`. TRUE = dated exposure before
  `t0_day`. FALSE = t0 known and nothing dated before it, including no evidence or only undated
  evidence. NULL only when `t0_day` is NULL, which keeps the subject out of the trial view.
  `*_any_bool` is exposure at any time, FALSE when there is no evidence.
- [decided] 2026-09-30, Andy: ACNS0334 excludes any prior chemotherapy, so prior methotrexate
  excludes from `pcx__eligible_trial` like the six backbone agents.
- [decided] 2026-09-30, Andy: MedicationDispense hand-overs (`core__medicationdispense`
  `whenhandedover_day`, cancelled and declined dropped) are structured evidence beside
  MedicationRequest orders. A dispense is closer to receipt than an order but is not proof of
  administration.
- [source] Not computable: organ-function laboratories, staging and residual disease as criteria
  (reported, not applied); sPNET arm never enters the trial view.
- [decided] Workplan 2.1-2.2 closed by the flags above: a child with t0 and no therapy records
  counts as "no prior therapy" and can enter the trial view. This is an absence of records, not
  a documented absence, so it depends on how complete the site's medication and procedure data are.
- [open] Workplan 1.7-1.8: month arithmetic, `varchar = integer` and `DATE(varchar)` behave
  differently on DuckDB and Athena.

## 7. Outcomes

SQL in `cumulus_library_pcx/sql/custom/outcome/`, opt-in stage `outcome`.

- [source limitations] Vital status (`outcome_vital_status.sql`): raw `patient.deceasedBoolean` /
  `deceasedDateTime`, the last study-population encounter, and LLM vital-status mentions; the
  earliest death and latest alive dates win without cross-checking.
- [source limitations] First event (`outcome_first_event.sql`) supports a provisional EFS; a death
  recorded only by the event task reaches EFS but not OS. Coarse LLM dates are consumed as exact days.
- [source] Exposure timing (`outcome_exposure.sql`): first methotrexate and chemotherapy days by
  source. Structured exposure is orders and pharmacy dispenses, not administration; LLM
  ADMINISTERED mentions are the only receipt evidence, and every administered agent counts as
  chemotherapy (workplan 3.4).

## 8. Analysis

### 8.1 Counts

- [source cubes.json] 17 count tables covering the study population, coded
  variables and case-definition cohort; names, sources and dimensions unchanged since
  the migration. Each table's description states its population and counted unit.
- [decided] 2026-09-22: defined in `counts.workflow`, built and exported by the shared
  `counts` stage (counts skill), replacing the former `stage/cube.py` and `cubes.json`. The
  file is `cumulus_library_pcx/counts.workflow`, at the package root next to `manifest.toml`.
  All tables are shared (`export:counts`); no site-only file.
- [decided] Every table counts distinct patients (`subject_ref`) with the builder floor
  of 10. The encounter, DocumentReference and DiagnosticReport tables count the resource
  through `secondary_id`: a cell needs 10 patients and 10 resources, and `cnt` is the
  resource count. Rows with a null patient or resource ID are excluded first.
- [decided] `cube_patient_variable_union` takes `age_group` from the linked
  study-population encounter (join on `encounter_ref_link`); evidence without a linked
  encounter is not counted, as before. `cube_patient_casedef` reads age group and gender
  from `cohort_casedef` itself; the former `_source` join tables are gone.
- [decided] 2026-10-05, Andy: `cube_encounter_study_population_enc` drops `age_at_visit` and
  keeps `age_group`. With ages 0-120, single years would add many small suppressed cells.
- [open] Output column order changed for `cube_patient_variable_union` (`age_group` is now
  last); the values and names are the same. Counts have not been run in the warehouse.

### 8.2 Exports and statistical plan

- [decided] Scope: exports only. The opt-in `client_views` stage produces the flat client tables
  (`cumulus_library_pcx/sql/custom/client_views/`, dictionary `spreadsheet/client_dictionary.csv`);
  no new estimand was introduced by the migration.
- [decided] No biostats stage: the 0.4 starter's demonstration scaffold was removed in the 0.5.0
  move. `spreadsheet/data_dictionary.csv` is Cumulus Library's column dictionary
  (`cumulus_library_pcx/manifest.toml`); a builder biostats contract would be
  `spreadsheet/biostats_dictionary.csv`.
- [open] No treatment-effect analysis, estimand, covariate set or censoring rule is specified.

## 9. Open questions

- [open] The diagnosis task version (section 5).
- [open] The original `reviews/` were not migrated. The query topics are back, as one
  `<topic>.txt` per topic in `spreadsheet/query_topics_ppv/` and `query_topics_recall/`
  (2026-10-08).
- [open] Inherited workplan 1.7, 1.8, 2.3-2.7, 3.4, 3.5 (sections 3-7): keep, schedule or close.
- [open] Review 2026-09-19, tracked in WORKPLAN.md:
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
- 2026-10-02 [decided] This study replaces the make-pcx version in the PCX repository: the
  make-pcx version is tagged `0.2-pre-study-builder`, the study-builder version lands on branch
  `andy/study-builder`. The 0.5.0 move is done now, with a flat `cumulus_library_pcx/` package
  (not `src/`), verified against the unreleased 0.5.0 builder checkout. Andy.
- 2026-10-02 [decided] The first data-only PyPI release is `cumulus-library-pcx` 0.3.0 with the
  default stages without NLP: `study_population`, `study_variable`, `study_variable_wide`,
  `casedef`, `sample`, `counts`, `study_meta`. The NLP stages, `eligible`, `outcome`,
  `client_views` and `qa_athena` wait for a later release. The builder is installed from its
  `v0.5.0` git tag (`comorbidity/cumulus-study-builder`, SSH). Andy.
- 2026-10-05 [decided] Ported from tag `0.2-pre-study-builder`: medications from Cumulus Library
  core with MedicationDispense as structured evidence, eligibility criteria as flags with the
  strict trial view (methotrexate counts as prior chemotherapy), prior-therapy flags FALSE for
  undated evidence and NULL only without a t0, ages 0-120 with adult age groups. The encounter
  count table drops `age_at_visit`. Andy.
- 2026-10-05 [decided] Release 0.3.0 is built by the local script `release/make_data_release.py`
  (venv, render, assemble, check, build) and published by hand with twine straight to PyPI,
  without TestPyPI, from `andy/study-builder` before the PR merges. The DuckDB smoke test of
  the installed package is deferred to a later release. Andy.
- 2026-10-07 [decided] The builder repository moved to `smart-on-fhir/cumulus-study-builder`;
  install and release use that URL. Tag `v0.5.0` is the same commit (7fc9700). Andy.
- 2026-10-08 [decided] The study moves to builder 0.5.2 (git tag `v0.5.2`): 0.5.1 reads the
  query-topic folder and 0.5.2 lets the Elasticsearch upload workflow be written beside its
  export, outside the study. `pyproject.toml` requires `>=0.5.2,<0.6`. Andy.
- 2026-10-08 [decided] The study moves to builder 0.5.3 (`>=0.5.3,<0.6`): the `elastic_upload`
  stage always builds `pcx__elastic_union`, empty at a site with no Elasticsearch export, so
  SQL that reads it runs at every site. Andy.
- 2026-10-08 [decided] `elastic_upload` is a default stage, placed before `sample`, and ships in
  the release rendered without an export: CHOP gets the empty `pcx__elastic_union`. At a site
  with an export, a default build uploads the export CSVs. `llm_schema` is opt-in. Andy.
- 2026-10-08 [decided] The study moves to builder 0.5.4 (`>=0.5.4,<0.6`): the `sample` stage
  builds `pcx__sample_task`, every casedef note (topic `casedef`) plus every Elasticsearch
  note (its search topic). Andy.
- 2026-10-08 [decided] Both `_50k` workflows are removed. `nlp_document_tasks_50k.workflow` was
  identical to `nlp_document_tasks.workflow`. Each task now has one definition and one
  version. Andy.
- 2026-10-08 [decided] Release 0.3.0 ships the eight default stages, built on builder 0.5.4.
  The NLP stages follow in a later release. Andy.
- 2026-10-08 [decided] The study moves to builder 0.5.5, which removes the NLP selector guard:
  each workflow is one manifest entry. The document tasks select from `pcx__sample_task`, which
  always has rows because `pcx__sample_casedef` is never empty. Andy.
- 2026-10-08 [decided] CHOP runs `gpt-oss-120b` on Bedrock, the same model as BCH, so the
  rendered wide SQL needs no site variant. Andy.
- 2026-10-08 [decided] Each clinical task selects the notes the LLM marked relevant to its
  topic (`document_topic` results). The selector tables are not built yet. Andy.
- 2026-10-08 [decided] Release 0.4.0 is the first with an LLM workflow, and its scope is
  `nlp_document_tasks.workflow` only (`document_type`, `document_topic`). The clinical
  workflow waits for a later release. Andy.
- 2026-10-07 [decided] CHOP runs the LLM on its own notes, so the release must carry the NLP
  stages. It stays data-only (SQL, TOML and JSON, no Python, no builder dependency) and
  Cumulus Library runs the workflows. Not yet verified by a run; see WORKPLAN. Andy.

## Agent rules

_Study-specific instructions for coding agents working in this repository (unnumbered;
not checked by `cumulus-study validate`)._
