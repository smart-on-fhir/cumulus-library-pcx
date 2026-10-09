# cumulus-study (building PCX)

PCX is built with `cumulus-study`, the command of
[cumulus-study-builder](https://github.com/smart-on-fhir/cumulus-study-builder). It renders
the SQL, the stage TOMLs and [manifest.toml](cumulus_library_pcx/manifest.toml) from their
sources. It runs nothing in the warehouse: `cumulus-library build` does that. This page
replaces the old `make-pcx` manual (git tag `0.2-pre-study-builder`).

## Set up

cumulus-study-builder 0.5.5 is the git tag `v0.5.5`, not on PyPI: installing it needs SSH
read access to `smart-on-fhir/cumulus-study-builder`.

```sh
python -m venv .venv && source .venv/bin/activate
python -m pip install -c requirements-tested.txt "git+ssh://git@github.com/smart-on-fhir/cumulus-study-builder.git@v0.5.5"
python -m pip install -c requirements-tested.txt -e '.[test]'
```

[requirements-tested.txt](requirements-tested.txt) pins the versions of the last passing run.

## Commands

Run them from the repository root.

| Command | What it does |
|---|---|
| `cumulus-study build` | Render every stage in build order, then write `manifest.toml` and check the result |
| `cumulus-study build STAGE ...` | Render only the named stages. `manifest.toml` is not rewritten |
| `cumulus-study stages` | List the stage names in build order |
| `cumulus-study validate` | Check the configuration, stage order, SQL dependencies and NLP note selections |
| `cumulus-study status` | Show the study paths, stages, and whether skills and starter files are current |
| `cumulus-study skills sync` / `skills check` | Copy the builder's agent skills into `.agents/skills`, or check they are current |
| `cumulus-study starter sync` / `starter check` | Update or check the files the builder's starter manages |

The usual routine after a change:

```sh
cumulus-study build
cumulus-study validate
python -m pytest -q
```

`tests/column_contracts.json` declares the FHIR tables and columns the study expects from a
site. The tests check the generated SQL against that declaration. They cannot certify a
site's real warehouse schema.

## Run in the warehouse

After site review, in a configured Cumulus environment:

```sh
cumulus-library build --study-dir cumulus_library_pcx                    # the default stages
cumulus-library build --study-dir cumulus_library_pcx --stage eligible   # one opt-in stage
```

Opt-in stages run only when named. Rendering never runs NLP, exports or queries.

## Stages

The build order is the `STAGES` list in
[stage/manifest.py](cumulus_library_pcx/stage/manifest.py), the single source for
`manifest.toml`.

| Stage | Runs | Owner | Purpose |
|---|---|---|---|
| `study_population` | default | builder | encounters for the study population (age, utilization, study period) |
| `study_variable` | default | builder | upload the [spreadsheet/](spreadsheet) valuesets, one `pcx__cohort_<variable>` each |
| `study_variable_wide` | default | builder | union and wide tables over the variable cohorts |
| `casedef` | default | builder | case-definition cohort from [casedef.csv](spreadsheet/casedef.csv) |
| `elastic_upload` | default | builder | load Elasticsearch results into `pcx__elastic_union`; an empty table when there is no export |
| `sample` | default | builder | note samples for the casedef cohort, and `pcx__sample_task` |
| `llm_schema` | opt-in | PCX | JSON schemas and summaries from the models in `llm/models/` ([LLM.md](llm.md)) |
| `nlp_document_tasks` | opt-in | PCX workflow | notes → LLM document type and topic |
| `llm_document_wide` | opt-in | builder | document type and topic results → wide SQL |
| `nlp_clinical_tasks` | opt-in | PCX workflow | notes → the 12 LLM clinical tasks |
| `llm_clinical_wide` | opt-in | builder | clinical results → 21 wide projections |
| `eligible` | opt-in | PCX | trial inclusion and exclusion flags ([eligible.md](eligible.md)) |
| `outcome` | opt-in | PCX | vital status, first event, OS and provisional EFS |
| `client_views` | opt-in | PCX | `pcx__client_*` tables for timeline and survival analysis |
| `qa_athena` | opt-in | PCX | `pcx__qa_*` and `pcx__warn_*` data-quality tables |
| `counts` | default | builder | the count tables in [counts.workflow](cumulus_library_pcx/counts.workflow) |
| `study_meta` | default | builder | study metadata tables |

"PCX" stages are modules in `cumulus_library_pcx/stage/`. "Builder" stages come from the
installed builder. To add or reorder a stage, edit `STAGES`. `elastic_upload` must stay
before `sample`, because `pcx__sample_task` reads `pcx__elastic_union`.

## Settings

[cumulus-study.toml](cumulus-study.toml) is read by every command.

| Setting | Meaning |
|---|---|
| `[study] directory` | the study package, `cumulus_library_pcx` |
| `[study] manifest` | the stage list, `stage/manifest.py` |
| `sample_patient_limit`, `sample_note_limit` | note-sampling limits per window (10 patients, 50 notes) |
| `data_package_version` | the data package version (2) |
| `nlp_deployments` | the models whose result tables the wide SQL reads (`gpt_oss_120b`) |
| `external_tables` | tables a site supplies, so `validate` does not expect a stage to build them: the 12 clinical note-selection tables |

The study prefix `pcx` is set only in `manifest.toml`.

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `ELASTIC_OUTPUT_DIR` | `$CUMULUS_LIBRARY_DATA_PATH/elastic/output` | where `elastic_upload` looks for Elasticsearch result CSVs. With neither variable set, or no CSVs, the stage builds an empty `pcx__elastic_union` |
| `CUMULUS_LIBRARY_DATA_PATH` | none | fallback for the folder above; `cumulus-library build` has its own uses for it |
| `HOME_INSTITUTION` | `Boston Children's Hospital (BCH)` | named in the `transition_of_care` prompts; set it to your site before `llm_schema` |
| `CUMULUS_PCX_STRICT_MENTIONS` | off | `1` makes the LLM model validators raise on missing evidence spans or bad dates. The default only warns; the test suite forces strict |
| `CUMULUS_ENCOUNTER_REF` | `encounter_ref_link` | which encounter link the templates use: `encounter_ref_link` (also attaches evidence by date) or `encounter_ref` (the FHIR Encounter reference only) |

## Site requirements

Beyond the Cumulus `core__` tables, the SQL reads these objects, which the site's ETL must
expose:

| Object | Read by | Purpose |
|---|---|---|
| `etl__completion_encounters` | `sample` (default) | note availability per encounter |
| `rxnorm.rxcui_str_longest` | `study_population` (default) | medication display names |
| `loinc.consumer_name` | `study_population` (default) | lab and report display names |
| raw `patient` | `outcome` (opt-in) | `deceasedBoolean`, `deceasedDateTime`, which `core__patient` does not carry |
| raw `encounter` | `client_views` (opt-in) | encounter class and type |
| `pcx__nlp_<task>_<deployment>` | `llm_document_wide`, `llm_clinical_wide` (opt-in) | raw LLM results, written by the NLP stages |
| `pcx__llm_document_task_<task>` | `nlp_clinical_tasks` (opt-in) | note-selection tables; no stage builds them yet ([WORKPLAN.md](WORKPLAN.md)) |

## Tables

Column dictionaries: [data_dictionary.csv](spreadsheet/data_dictionary.csv) for the cohort,
casedef, sample, eligible and outcome tables, and
[client_dictionary.csv](spreadsheet/client_dictionary.csv) for the `pcx__client_*` tables.

| Table | Role |
|---|---|
| `core__` | simplified FHIR views from Cumulus core |
| `pcx__include_*` | study period, age and encounter utilization criteria for the study population |
| `pcx__valueset_*` | CSV files as SQL valuesets (system, code, display, tier or keyword) |
| `pcx__cohort_study_period` | study period and history flag |
| `pcx__cohort_study_population*` | eligible encounters and linked FHIR resources (enc, dx, rx, lab, proc, doc, diag, allergy) |
| `pcx__cohort_dx_*`, `_lab_*`, `_proc_*`, `_rx_*` | coded cohorts matching the CSV valueset of the same name |
| `pcx__cohort_variable_union*` | all coded evidence in one long table, per aspect |
| `pcx__cohort_variable_wide*` | one row per resource with typed metadata, per aspect |
| `pcx__cohort_casedef*` | coded case-definition evidence, per-subject anchor and pre / peri / post periods |
| `pcx__cohort_timeline` | encounter timeline relative to the casedef anchor |
| `pcx__elastic_union` | notes found by the Elasticsearch topics; empty at a site without an export |
| `pcx__sample_*` | candidate clinical notes; `pcx__sample_task` is the casedef notes plus the Elasticsearch notes |
| `pcx__nlp_<task>_<deployment>` | raw LLM output per task and model deployment |
| `pcx__llm_*` | LLM chart abstraction flattened to SQL (wide tables, one table per list-valued mention) |
| `pcx__eligible_*` | per-subject eligibility criteria (`pcx__eligible`, all ages) and the trial-like intersection (`pcx__eligible_trial`) |
| `pcx__outcome_*` | per-subject vital status, first event, exposure timing, OS and EFS |
| `pcx__client_*` | timeline of eligibility, outcomes and variables, for export |
| `pcx__qa_*` | QA tables; their union should have 0 rows |
| `pcx__warn_*` | data-quality warnings; nonzero rows are findings to look at |

Aliases used in table and column names:

| Alias | FHIR resource |
|---|---|
| `enc` | Encounter |
| `dx` | Condition |
| `diag` | DiagnosticReport |
| `doc` | DocumentReference |
| `note` | DocumentReference or DiagnosticReport |
| `lab` | Observation (category laboratory) |
| `proc` | Procedure |
| `rx` | MedicationRequest |
| `allergy` | AllergyIntolerance |

## Input and output

Edit the inputs, never the outputs.

| Input | Used by |
|---|---|
| `spreadsheet/include_*.csv`, `age_group.csv` | `study_population` |
| `spreadsheet/dx_*.csv`, `rx_*.csv`, `lab_*.csv`, `proc_*.csv` | `study_variable` |
| `spreadsheet/casedef.csv` | `casedef` |
| `spreadsheet/query_topics/*.txt` | Elasticsearch queries ([rapid-elastic.md](rapid-elastic.md)) |
| `spreadsheet/client_dictionary.csv` | `client_views` |
| `cumulus_library_pcx/sql/custom/` | study SQL for `eligible`, `outcome`, `client_views` |
| `cumulus_library_pcx/sql/template/` | Jinja templates, including the LLM wide projections |
| `cumulus_library_pcx/llm/models/` | the LLM extraction models |
| `cumulus_library_pcx/nlp_*.workflow`, `counts.workflow` | workflows, written by hand |

| Output | By |
|---|---|
| `cumulus_library_pcx/sql/generated/*.sql` | every rendered stage |
| `cumulus_library_pcx/<stage>.toml` | each stage |
| `cumulus_library_pcx/manifest.toml` (the `stages` part) | a full `cumulus-study build` |
| `cumulus_library_pcx/llm/schemas/`, `llm/summaries/` | `llm_schema` (git-ignored) |
| `$ELASTIC_OUTPUT_DIR/file_upload_elastic.toml` | `elastic_upload`, when result CSVs exist |

## Release

The PyPI package `cumulus-library-pcx` is data-only: the rendered SQL and data files of the
eight default stages plus `nlp_document_tasks`, the JSON response schemas of every LLM task,
no Python code and no dependencies. The release runs `nlp_document_tasks` (document type and
topic) by default; the clinical NLP tasks ship only as schemas. Sites install it next to
Cumulus Library and run `cumulus-library build -t pcx`.

```sh
python release/make_data_release.py     # needs SSH read access to the builder repository
```

Run it with the development venv from [Set up](#set-up) active: the script finds the repository
through the builder's `filetool`, so the builder must be installed in the Python that runs it.

The script works in `build/release/` (remove it before the next run): a venv with the
builder tag, `cumulus-study build` and `validate`, the assembled package, checks, then the
wheel and sdist in `build/release/dist/`. The version comes from `pyproject.toml`. It never
uploads or runs git: it prints the `twine upload` command for the person publishing.
