# PCX study of pediatric brain cancers

This study is a retrospective, proof of concept, EHR emulation of clinical trial [ACNS0334](https://clinicaltrials.gov/study/NCT00336024?term=ACNS0334); 
read about it here [PMC12833527](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527):

> "Phase 3 randomized trial of high-dose methotrexate for young children with high-risk embryonal brain tumors: A report from the Children's Oncology Group"

The [eligibility criteria](eligible.md) describes how the EHR data is used to emulated the clinical trial. As a proof of concept study, not all 100% of the trial eligibility criteria will be met in this phase, this study will be refined with more stringent inclusion/exclusion rules as the study matures. 

The primary outcome is **patient survival**; the secondary outcomes are EFS (event free survival) where event here is defined as cancer **progression** or cancer **recurrence**.   

This study uses EHR data from FHIR coded resources as well as clinical narratives (notes). 

## Table of Contents  
* [Install](#install)
* [Build](#build)
  * [Stages](#stages)
* [Data Dictionary](#data-dictionary)

## Install

```commandline
git clone git@github.com:smart-on-fhir/cumulus-library-pcx.git

cd cumulus-library-pcx

# install
python3 -m venv ve
source ve/bin/activate
pip3 install -e .
```

## Build

Prerequirement: [cumulus-library](https://docs.smarthealthit.org/cumulus/library/)  

```commandline
python3 cumulus_library_pcx/tools/study_builder.py
cumulus-library build -s . -t pcx --stage all
```

### Stages

[manifest.toml](cumulus_library_pcx/manifest.toml) defines the build stages, in order: 

| stage                                                                            | purpose                                                                                                                                                                                                                         |
|----------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [study_population](cumulus_library_pcx/study_population.toml)               | select encounters for all patients under 3 years old with up to 5 years of followup                                                                                                                                             |
| [study_variable](cumulus_library_pcx/study_variable.toml)                   | upload [CSV valuesets](/Users/andy/chip/cumulus-library-pcx/spreadsheet) for FHIR coded diagnosis (MB,ATRT), procedures (surgery, radiation), medication (Chemo, Methotrexate). Each CSV file becomes a `pcx__cohort_$variable` |
| [study_variable_wide](cumulus_library_pcx/study_variable_wide.toml)         | enrich metadata for each **variable cohort** by type (dx,rx,proc)                                                                                                                                                               |
| [casedef](cumulus_library_pcx/casedef.toml)                                 | select patient cohorts matching a coded "case definition"                                                                                                                                                                       |
| [sample](cumulus_library_pcx/sample.toml)                                   | from the casedef cohort, get clinical note samples (FHIR DiagnosticReport, FHIR DocumentReference)                                                                                                                              |
| [elastic_query](cumulus_library_pcx/elastic_query.toml)                     | (optional) find more patient cases using full text search (requires server and client [rapid-elastic](https://github.com/smart-on-fhir/rapid-elastic)                                                                           | 
| [elastic_output](cumulus_library_pcx/elastic_output.toml)                   | (optional) load elastic search results into SQL database                                                                                                                                                                        |
| [nlp_clinical_tasks](cumulus_library_pcx/nlp_clinical_tasks.toml)           | Notes -> LLM                                                                                                                                                                                                                    |
| [nlp_clinical_tasks_wide](cumulus_library_pcx/nlp_clinical_tasks_wide.toml) | LLM -> SQL tables                                                                                                                                                                                                               |
| [eligible](cumulus_library_pcx/eligible.toml) | inclusion/exclusion criteria (dx, rx, radiation, surgery), see [eligible.md](eligible.md)                                                                                                                                       |
| [outcome](cumulus_library_pcx/outcome.toml) | primary outcome is death; secondary outcomes: cancer progression, recurrence.                                                                                                                                                   |
| [client_views](cumulus_library_pcx/client_views.toml) | build `pcx__client` tables for timeline/time-series analysis, especially [Kaplan-Meir](https://pmc.ncbi.nlm.nih.gov/articles/PMC3059453/) survival pots                                                                         | 
| [qa_athena](cumulus_library_pcx/qa_athena.toml) | PCX specific data quality checks, table prefixes: `pcx__qa` and `pcx__warn`                                                                                                                                                     | 


## Data Dictionary

* [data_dictionary.csv](spreadsheet/data_dictionary.csv) all columns all tables  
* [client_dictionary.csv](spreadsheet/client_dictionary.csv) (recommended) use `pcx__client` tables 

| Table                           | Role                                                                                                             |
|---------------------------------|------------------------------------------------------------------------------------------------------------------|
| `core__`                        | Simplified FHIR views from Cumulus CORE                                                                          |
| `pcx__include_*`                | Encounter utilization criteria for overall "study population"                                                    |
| `pcx__valueset_*`               | CSV files as SQL valuesets (system, code, display)                                                               |
| `pcx__cohort_study_population*` | Eligible encounters and FHIR resources                                                                           |
| `pcx__cohort_variable_*`        | Coded PCX cohorts matching CSV valueset by same name                                                             |
| `pcx__cohort_casedef*`          | Coded PCX case-definition evidence                                                                               |
| `pcx__sample_*`                 | Candidate clinical notes                                                                                         |
| `pcx__llm_*`                    | LLM triage and chart abstraction                                                                                 |
| `pcx__eligible_*`               | Cohort of PCX eligible patients                                                                                  |
| `pcx__outcome_*`                | Cohort of PCX eligible patient outcomes                                                                          |
| `pcx__client_*`                 | Timeline of PCX eligibility, outcomes, variables; see [client_dictionary.csv](spreadsheet/client_dictionary.csv) |
| `pcx__qa_*`                     | QA tables, union should be empty (0 rows)                                                                        |
| `pcx__warn_*`                   | WARN tables (data quality warnings)                                                                              |

### Common Aliases

| Alias   | FHIR Resource                           |
|---------|-----------------------------------------|
| `enc`   | Encounter                               |
| `dx`    | Condition                               |
| `diag`  | DiagnosticReport                        |
| `doc`   | DocumentReference                       |
| `note`  | DocumentReference _or_ DiagnosticReport |
| `lab`   | Observation (category=Laboratory)       |
| `proc`  | Procedure                               |
| `rx`    | MedicationRequest                       |
