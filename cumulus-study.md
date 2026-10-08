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
| `llm_schema` | opt-in | PCX | JSON schemas and summaries from the models in `llm/models/` ([LLM.md](LLM.md)) |
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
eight default stages without NLP, no Python code and no dependencies. Sites install it next
to Cumulus Library and run `cumulus-library build -t pcx`.

```sh
python release/make_data_release.py     # needs SSH read access to the builder repository
```

Run it with the development venv from [Set up](#set-up) active: the script finds the repository
through the builder's `filetool`, so the builder must be installed in the Python that runs it.

The script works in `build/release/` (remove it before the next run): a venv with the
builder tag, `cumulus-study build` and `validate`, the assembled package, checks, then the
wheel and sdist in `build/release/dist/`. The version comes from `pyproject.toml`. It never
uploads or runs git: it prints the `twine upload` command for the person publishing.
