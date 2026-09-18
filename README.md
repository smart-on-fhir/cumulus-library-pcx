# PCX study of pediatric brain cancers

This study is a retrospective, proof of concept, EHR emulation of clinical trial [ACNS0334](https://clinicaltrials.gov/study/NCT00336024?term=ACNS0334);
read about it here [PMC12833527](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527):

> "Phase 3 randomized trial of high-dose methotrexate for young children with high-risk embryonal brain tumors: A report from the Children's Oncology Group"

👀 [eligible.md](eligible.md) describes EHR data for emulation of this clinical trial. As a proof of concept study, not all 100% of the trial eligibility criteria will be met in this phase; this study will be refined with more stringent inclusion/exclusion rules as the study matures.

The primary outcome is **patient survival** (censored at last known alive); the secondary outcome is EFS (event free survival), where an event is cancer **progression**, cancer **recurrence**, a **second malignancy**, or **death**. EFS is provisional until event-free follow-up is adjudicated (see [limitations.md](limitations.md)).

This study uses EHR data from FHIR coded resources as well as clinical narratives (notes).


## Table of Contents
* [Install](#install)
* [Build](#build)
  * [Environment](#environment)
  * [Site requirements](#site-requirements)
  * [Stages](#stages)
* [Tests](#tests)
* [Data Dictionary](#data-dictionary)
* [Documentation](#documentation)

## Install

```commandline
git clone git@github.com:smart-on-fhir/cumulus-library-pcx.git

cd cumulus-library-pcx

# install
python3 -m venv ve
source ve/bin/activate
pip3 install -e .
```

`pip3 install -e .` pulls `rapid-elastic` from GitHub (needed only by the optional Elastic stages) and `cumulus-library >= 6.3.1`.

## Build

Prerequirement: [cumulus-library](https://docs.smarthealthit.org/cumulus/library/)

```commandline
# regenerate the athena SQL, the *.toml submanifests and manifest.toml from the CSVs and templates
make-pcx

# the same, then build every stage that is not skip_by_default
make-pcx --build

# regenerate (and build) one stage
make-pcx casedef --build
```

`make-pcx` is installed by `pip3 install -e .`; see [make-pcx.md](make-pcx.md) for the commands, the stage list and what is generated versus hand-written. Never hand-edit `cumulus_library_pcx/athena/*.sql`, the generated tomls or `manifest.toml`; edit the CSVs in [spreadsheet/](spreadsheet) or the templates in [cumulus_library_pcx/template/](cumulus_library_pcx/template) and rerun `make-pcx`. The SQL under [cumulus_library_pcx/custom/](cumulus_library_pcx/custom) (eligible, outcome, client views) is hand-written.

### Environment

| variable                      | required | purpose                                                                                                                                                                  |
|-------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `CUMULUS_LIBRARY_DATA_PATH`   | build    | root of Cumulus data exports; also the fallback for `ELASTIC_OUTPUT_DIR`. Not needed by `make-pcx`                                                                        |
| `ELASTIC_OUTPUT_DIR`          | no       | where the optional `elastic_upload` stage looks for Elastic result CSVs; default `$CUMULUS_LIBRARY_DATA_PATH/elastic/output`                                            |
| `HOME_INSTITUTION`            | no       | institution name interpolated into the transition-of-care LLM prompt and schema. The default in `settings.py` currently does not apply because of a precedence bug (1.3) |
| `CUMULUS_PCX_STRICT_MENTIONS` | no       | `1` makes the LLM model validators raise on missing spans / bad dates; default is warn-only (the test suite forces strict)                                               |
| `CUMULUS_ENCOUNTER_REF`       | no       | `encounter_ref_link` (default, date-rescued linkage) or `encounter_ref` (FHIR Encounter reference only)                                                                   |
| `CUMULUS_CUBE_AS_VIEW`        | no       | build patient-count cubes as views instead of tables                                                                                                                        |
| `CUMULUS_CUBE_MIN_SUBJECTS`   | no       | minimum patients per cube cell, default 10                                                                                                                                |

### Site requirements

Beyond the Cumulus `core__` tables, the build reads these objects, which the site ETL must expose:

| object                              | used by                                                                | purpose                                                              |
|-------------------------------------|------------------------------------------------------------------------|----------------------------------------------------------------------|
| `core__patient`, `core__encounter`  | study_population, eligible                                             | demographics, encounter periods, birthdate for age in months        |
| raw `patient`                       | outcome (`pcx__outcome_vital_status`)                                  | `deceasedBoolean`, `deceasedDateTime` (core__patient does not carry them) |
| raw `encounter`                     | client_views (`pcx__client_encounter`)                                 | encounter class and type                                             |
| `etl__completion_encounters`        | sample                                                                 | note availability per encounter                                      |
| `rxnorm.rxcui_str_longest`          | study_population (rx)                                                  | medication display names                                             |
| `loinc.consumer_name`               | study_population (lab, diag)                                           | lab and report display names                                         |
| `pcx__nlp_<task>_<deployment>`      | nlp_clinical_wide                                                | raw LLM output tables written by the NLP stages                      |
| `pcx__llm_document_task_<task>`     | the NLP `.workflow` files                                              | note selection tables; nothing in the repo creates them yet (4.1)   |

### Stages

[manifest.toml](cumulus_library_pcx/manifest.toml) defines the build stages, in order; `make-pcx` writes it from the `STAGES` list in [stage/manifest.py](cumulus_library_pcx/stage/manifest.py). "on" means the stage runs under `--stage all`; "skip" means it is registered with `skip_by_default` and must be selected explicitly (`make-pcx <stage> --build`).

| stage                                                                         | state | purpose                                                                                                                                                                                                                                                   |
|-------------------------------------------------------------------------------|-------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [study_population](cumulus_library_pcx/study_population.toml)                 | on    | select encounters for patients aged 0–8 at the visit ([include_age_at_visit.csv](spreadsheet/include_age_at_visit.csv)) with ≥ 2 encounters spanning ≥ 365 days ([include_utilization.csv](spreadsheet/include_utilization.csv)), study period from 2008 |
| [study_variable](cumulus_library_pcx/study_variable.toml)                     | on    | upload [CSV valuesets](spreadsheet) for FHIR coded diagnosis (MB, ATRT, brain cancer, radiation, methotrexate toxicity), procedures (craniotomy, radiation), medication (chemo, methotrexate), and 7 lab tests. Each CSV becomes a `pcx__cohort_$variable` |
| [study_variable_wide](cumulus_library_pcx/study_variable_wide.toml)           | on    | enrich metadata for each **variable cohort** by type (dx, lab, proc, rx)                                                                                                                                                                                  |
| [casedef](cumulus_library_pcx/casedef.toml)                                   | on    | select patient cohorts matching the coded "case definition" ([casedef.csv](spreadsheet/casedef.csv): medulloblastoma, atrt, etmr, pineoblastoma, cns_embryonal; tier 1 = diagnostic, tier 2 = supporting)                                                  |
| [sample](cumulus_library_pcx/sample.toml)                                     | on    | from the casedef cohort, get clinical note samples (FHIR DiagnosticReport, FHIR DocumentReference) by pre / peri / post period                                                                                                                             |
| [elastic_query](cumulus_library_pcx/elastic_query.toml)                       | skip  | (optional) find more patient cases using full text search (requires server and client [rapid-elastic](https://github.com/smart-on-fhir/rapid-elastic)). See [query_topics.md](query_topics.md)                                                             |
| [elastic_upload](cumulus_library_pcx/elastic_upload.toml)                     | on    | (optional) load elastic search results into SQL. Reads `ELASTIC_OUTPUT_DIR` (default `$CUMULUS_LIBRARY_DATA_PATH/elastic/output`); with no results the stage is generated empty                                                                          |
| [nlp_document_tasks_50k](cumulus_library_pcx/nlp_document_tasks_50k.workflow) | skip  | Notes -> LLM document topic routing (the full [nlp_document_tasks.workflow](cumulus_library_pcx/nlp_document_tasks.workflow) with document type is off). Wired as `submanifest`, which cumulus-library rejects (1.1)                                       |
| [nlp_clinical_tasks_50k](cumulus_library_pcx/nlp_clinical_tasks_50k.workflow) | skip  | Notes -> LLM for diagnosis and surgery (the full [nlp_clinical_tasks.workflow](cumulus_library_pcx/nlp_clinical_tasks.workflow) with all 14 tasks is off). Same wiring problem (1.1)                                                                       |
| [nlp_document_wide](cumulus_library_pcx/nlp_document_wide.toml)   | on    | LLM -> SQL: document type and topic-routing results, generated by [nlp_document_wide.py](cumulus_library_pcx/stage/nlp_document_wide.py)                                                                                                     |
| [nlp_clinical_wide](cumulus_library_pcx/nlp_clinical_wide.toml)   | on    | LLM -> SQL: 21 clinical projections generated by [nlp_clinical_wide.py](cumulus_library_pcx/stage/nlp_clinical_wide.py). Selected NLP source tables must exist. See [llm.md](llm.md#schema-generation-and-wide-outputs) |
| [eligible](cumulus_library_pcx/eligible.toml)                                 | on    | inclusion/exclusion criteria (dx, rx, radiation, surgery), see [eligible.md](eligible.md)                                                                                                                                                                 |
| [outcome](cumulus_library_pcx/outcome.toml)                                   | on    | vital status, first event, exposure timing relative to first event, OS and provisional EFS                                                                                                                                                                |
| [client_views](cumulus_library_pcx/client_views.toml)                         | on    | `pcx__client_*` tables for timeline / time-series analysis, especially [Kaplan-Meier](https://pmc.ncbi.nlm.nih.gov/articles/PMC3059453/) survival plots. Depends on the NLP wide tables (4.2–4.4)                                                       |
| [qa_athena](cumulus_library_pcx/qa_athena.toml)                               | on    | PCX data quality checks: 21 `pcx__warn_*` tables plus `pcx__warn_union` (no `pcx__qa_*` tables exist yet). See [reviews/qa-warn-2026-09-11/REVIEW.md](reviews/qa-warn-2026-09-11/REVIEW.md)                                                             |
| [cube](cumulus_library_pcx/cube.toml)                                         | on    | patient-count cubes over the study population, casedef, samples and variable union                                                                                                                                                                       |

## Tests

```commandline
export CUMULUS_LIBRARY_DATA_PATH=/some/path
python3 -m pytest -q   # run from the repository root
```

The SQL tests run the hand-written `custom/` SQL and the `tests/athena/` QA/WARN tables on DuckDB over the seeded fixtures in [tests/data/warn/](tests/data/warn) ([tests/data/schema.sql](tests/data/schema.sql) plus one CSV per table, loaded by `tests/sqltest.py`): `tests/test_eligible_outcome_sql.py` checks the trial-emulation rules, `test_warn_sql.py` asserts exactly which seeded subject each QA/WARN check fires on. `make-pcx test-synthetic` regenerates [tests/data/synthetic/](tests/data/synthetic), a larger synthetic population run through the same SQL (see [synthetic.md](synthetic.md)); `sqltest.connect(data_dir)` can load its upstream tables. The LLM tests (`test_llm_models.py`, `test_llm_strict_mode.py`, `test_nlp_wide_model_shape.py`, `test_nlp_clinical_wide.py`) currently have 40 failures and one collection error, mostly because `test_llm_builder_discovery.py` specifies a deployment-discovery design that is not yet implemented (workplan 1.5). DuckDB differs from Athena in ways the tests do not catch: month arithmetic, `varchar = integer`, `DATE(varchar)` on timestamps (workplan 1.6–1.8).

## Data Dictionary

* [data_dictionary.csv](spreadsheet/data_dictionary.csv) columns of the cohort, casedef, sample, eligible and outcome tables
* [client_dictionary.csv](spreadsheet/client_dictionary.csv) (recommended) columns and timeline variables of the `pcx__client` tables

| Table                            | Role                                                                                                                       |
|----------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| `core__`                         | Simplified FHIR views from Cumulus CORE                                                                                    |
| `pcx__include_*`                 | Study period, age and encounter utilization criteria for the overall "study population"                                   |
| `pcx__valueset_*`                | CSV files as SQL valuesets (system, code, display, tier or keyword)                                                        |
| `pcx__cohort_study_period`       | Study period and history flag                                                                                              |
| `pcx__cohort_study_population*`  | Eligible encounters and linked FHIR resources (enc, dx, rx, lab, proc, doc, diag, allergy)                                 |
| `pcx__cohort_dx_*`, `_lab_*`, `_proc_*`, `_rx_*` | Coded PCX cohorts matching the CSV valueset of the same name                                                   |
| `pcx__cohort_variable_union*`    | All coded evidence in one long table, per aspect                                                                           |
| `pcx__cohort_variable_wide*`     | One row per resource with typed metadata, per aspect                                                                       |
| `pcx__cohort_casedef*`           | Coded PCX case-definition evidence, per-subject anchor and pre / peri / post periods                                        |
| `pcx__cohort_timeline`           | Encounter timeline relative to the casedef anchor                                                                          |
| `pcx__sample_*`                  | Candidate clinical notes                                                                                                   |
| `pcx__nlp_<task>_<deployment>`   | Raw LLM output per task and model deployment                                                                               |
| `pcx__llm_*`                     | LLM chart abstraction flattened to SQL (wide tables, one table per list-valued mention)                                    |
| `pcx__eligible_*`                | Per-subject eligibility criteria (`pcx__eligible`, all ages) and the trial-like intersection (`pcx__eligible_trial`)       |
| `pcx__outcome_*`                 | Per-subject vital status, first event, exposure timing, OS and EFS                                                         |
| `pcx__client_*`                  | Timeline of PCX eligibility, outcomes, variables; see [client_dictionary.csv](spreadsheet/client_dictionary.csv)            |
| `pcx__qa_*`                      | QA tables, union should be empty (0 rows). None exist yet                                                                  |
| `pcx__warn_*`                    | WARN tables (data quality warnings), nonzero rows are findings to eyeball                                                  |

### Common Aliases

| Alias     | FHIR Resource                           |
|-----------|-----------------------------------------|
| `enc`     | Encounter                               |
| `dx`      | Condition                               |
| `diag`    | DiagnosticReport                        |
| `doc`     | DocumentReference                       |
| `note`    | DocumentReference _or_ DiagnosticReport |
| `lab`     | Observation (category=Laboratory)       |
| `proc`    | Procedure                               |
| `rx`      | MedicationRequest                       |
| `allergy` | AllergyIntolerance                      |

## Documentation

| file                                              | topic                                                                       |
|---------------------------------------------------|-----------------------------------------------------------------------------|
| [workplan.md](workplan.md)                        | ordered work items with acceptance criteria                                |
| [eligible.md](eligible.md)                        | how the trial criteria map onto the eligible stage                          |
| [limitations.md](limitations.md)                  | scientific gaps between the trial and the EHR emulation, current state      |
| [llm.md](llm.md)                                  | the LLM extraction models                                                   |
| [deferred.md](deferred.md)                        | model fields deliberately removed                                           |
| [laboratory.md](laboratory.md)                    | lab valuesets                                                               |
| [query_topics.md](query_topics.md)                | Elastic full-text retrieval topics                                          |
| [dx_methotrexate_toxic.md](dx_methotrexate_toxic.md) | methotrexate toxicity diagnosis valueset                                  |
| [reviews/](reviews)                               | dated code and terminology reviews (historical records, newest first below) |

Reviews: [2026-09-11 code review](reviews/code-review-2026-09-11/REVIEW.md), [2026-09-11 QA warn tables](reviews/qa-warn-2026-09-11/REVIEW.md), [2026-09-10 eligible/outcome notes](reviews/eligible-outcome-2026-09-10/NOTES.md), [2026-09-10 LLM models](reviews/llm-models-review-2026-09-10/REVIEW.md), [2026-09-09 code review](reviews/code-review-2026-09-09/REVIEW.md), [2026-09-09 methotrexate discovery](reviews/methotrexate-discovery-2026-09-09/README.md), [2026-09-08 RxNorm](reviews/rxnorm-2026-09-08/REVIEW.md).
