# make-pcx (command line interface)

Command-line front end to the study generator of the `cumulus-library-pcx` study:
renders the Athena SQL and the stage `*.toml` submanifests from their sources, writes
[manifest.toml](cumulus_library_pcx/manifest.toml), and optionally runs `cumulus-library build`.

* See [README.md](README.md) for what each stage computes;
* See [llm.md](llm.md) for the NLP stages, which this command lists but does not generate.

## Contents

- [Synopsis](#synopsis)
- [Commands](#commands)
- [Options](#options)
- [Stages](#stages)
- [Environment](#environment)
- [Input](#input)
- [Output](#output)
- [Code](#code)
- [Known issues](#known-issues)

## Synopsis

```
make-pcx [STAGE ...] [--build]
make-pcx --list
make-pcx test-synthetic [--patients N] [--seed S] [--noise X] [--no-utilization-screen] [--quiet]
```

`make-pcx` is installed by `pip3 install -e .` (`[project.scripts]` in [pyproject.toml](pyproject.toml)).
It reads and writes only beneath the study package [cumulus_library_pcx/](cumulus_library_pcx),
the CSV directory [spreadsheet/](spreadsheet) and, for `test-synthetic`, [tests/data/synthetic/](tests/data/synthetic);
it needs no environment variables of its own.

---
## Commands

> make-pcx

(default) make every stage in build order, then write `manifest.toml`. Each stage's `make()`
renders its SQL into `athena/` and writes `<stage>.toml`; the paths written are printed one per line.

> make-pcx STAGE ...

Make only the named stage(s). Names are validated first, so a typo exits with the list of
valid names and nothing is written. Stages are made in build order, whatever order they are
typed in. `manifest.toml` is not rewritten.

> make-pcx --build

Make, then run

```
cumulus-library build -s cumulus_library_pcx -t pcx --stage all --force-upload
```

With stage names, one `cumulus-library build --stage <name>` runs per name, in build order,
after the makes. Stages registered with `skip_by_default` are only built this way.
A hand-written stage (see [Stages](#stages)) has nothing to make; naming it with `--build`
just builds it.

> make-pcx --list

Print the stage names in build order and exit.

> make-pcx test-synthetic

Regenerate [tests/data/synthetic/](tests/data/synthetic): a synthetic, real-world-like cohort of
children 3 years old or younger with a CNS embryonal tumor, calibrated to ACNS0334
([PMC12833527](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/)), run through the real
`custom/pcx__eligible*.sql` and `pcx__outcome*.sql` in DuckDB. It writes the ten derived tables
as Athena-download CSV, `synthetic__truth.csv` (the latent truth per subject) and the upstream
tables in the [tests/data/warn](tests/data/warn) fixture style, all in one directory, plus
`test-synthetic.csv`, the report as one row per fact (`section, table, column, item, value, count,
percent, paper`: run options, calibration against the paper, and the characteristics of every
source table and column). Stale CSVs from an earlier
run are removed first. Options after the word go to the generator ([tests/synthetic.py](tests/synthetic.py),
test code kept out of the study package and loaded from the checkout, so this needs a clone with `pip install -e .`):
`--patients` (rows in `pcx__eligible`, default 1000), `--seed` (default 334), `--noise` (0 clean,
1 realistic), `--no-utilization-screen` (keep early deaths), `--quiet` (no calibration report).
`test-synthetic` is a command word, not a stage: `--list` does not show it and `--build` does not apply.
Needs `duckdb` and `numpy` (the `[test]` extra). See [synthetic.md](synthetic.md) for the design.

---
## Options

| Option    | Meaning                                                                                                  |
|-----------|----------------------------------------------------------------------------------------------------------|
| `STAGE`   | Zero or more stage names from `--list`. None means every stage plus `manifest.toml`.                     |
| `--build` | After making, run `cumulus-library build` for the selected stage(s), `all` when none is named. Requires `cumulus-library` on the PATH (the study venv); stops on the first failing build. |
| `--list`  | Print stage names and exit.                                                                              |
| `test-synthetic` | Command word (first argument): regenerate `tests/data/synthetic`; later arguments are generator options, see [Commands](#commands). |
| `-h`      | Usage.                                                                                                   |

---
## Stages

The build order is the `STAGES` list in [stage/manifest.py](cumulus_library_pcx/stage/manifest.py),
which is the single source of truth for `manifest.toml`. 

Each entry is a
`Stage` ([tools/staging.py](cumulus_library_pcx/tools/staging.py)) built from one of two targets:

* **a Python stage module** in [stage/](cumulus_library_pcx/stage): `make-pcx` calls its
  `make()`, which writes `<module name>.toml`. 

* **hand-written**  submanifest `.toml` or `.workflow`.  

Kind links to the stage's file: an **action** is a `.toml` submanifest of `[[actions]]` entries
(`type = "submanifest"` in `manifest.toml`); a **workflow** is a `.workflow` file with a
`config_type`, which cumulus-library runs through the matching builder.

| Stage                                                                   | Kind                                                            | `--stage all` | Purpose                                                                         |
|-------------------------------------------------------------------------|-----------------------------------------------------------------|---------------|---------------------------------------------------------------------------------|
| [study_population](cumulus_library_pcx/stage/study_population.py)       | [action](cumulus_library_pcx/study_population.toml)             | on            | encounters for the study population (age, utilization, study period)            |
| [study_variable](cumulus_library_pcx/stage/study_variable.py)           | [action](cumulus_library_pcx/study_variable.toml)               | on            | upload [spreadsheet/](spreadsheet) valuesets, one `pcx__cohort_<variable>` each |
| [study_variable_wide](cumulus_library_pcx/stage/study_variable_wide.py) | [action](cumulus_library_pcx/study_variable_wide.toml)          | on            | union and wide tables over the variable cohorts, by aspect                      |
| [casedef](cumulus_library_pcx/stage/casedef.py)                         | [action](cumulus_library_pcx/casedef.toml)                      | on            | case-definition cohort from [casedef.csv](spreadsheet/casedef.csv)              |
| [sample](cumulus_library_pcx/stage/sample.py)                           | [action](cumulus_library_pcx/sample.toml)                       | on            | clinical-note samples for the casedef cohort                                    |
| [elastic_query](cumulus_library_pcx/tools/elastic_query.py)             | [action](cumulus_library_pcx/elastic_query.toml)                | skip          | full-text search via `tools/elastic_query.py` (optional, needs rapid-elastic)   |
| [elastic_upload](cumulus_library_pcx/stage/elastic_upload.py)           | [action](cumulus_library_pcx/elastic_upload.toml)               | on            | load Elastic results into SQL; makes an empty stage when no results exist       |
| `nlp_document_tasks_50k`                                                | [workflow](cumulus_library_pcx/nlp_document_tasks_50k.workflow) | skip          | notes → LLM document-topic routing                                              |
| `nlp_clinical_tasks_50k`                                                | [workflow](cumulus_library_pcx/nlp_clinical_tasks_50k.workflow) | skip          | notes → LLM clinical tasks                                                      |
| [nlp_document_wide](cumulus_library_pcx/stage/nlp_document_wide.py) | [action](cumulus_library_pcx/nlp_document_wide.toml)      | on            | LLM document type and topic → wide SQL                                               |
| [nlp_clinical_wide](cumulus_library_pcx/stage/nlp_clinical_wide.py) | [action](cumulus_library_pcx/nlp_clinical_wide.toml)      | on            | LLM output → wide SQL projections                                               |
| [eligible](cumulus_library_pcx/stage/eligible.py)                       | [action](cumulus_library_pcx/eligible.toml)                     | on            | trial inclusion/exclusion, see [eligible.md](eligible.md)                       |
| [outcome](cumulus_library_pcx/stage/outcome.py)                         | [action](cumulus_library_pcx/outcome.toml)                      | on            | vital status, first event, OS and provisional EFS                               |
| [client_views](cumulus_library_pcx/stage/client_views.py)               | [action](cumulus_library_pcx/client_views.toml)                 | on            | `pcx__client_*` tables for timeline and survival analysis                       |
| [qa_athena](cumulus_library_pcx/stage/qa_athena.py)                     | [action](cumulus_library_pcx/qa_athena.toml)                    | on            | `pcx__qa_*` / `pcx__warn_*` data-quality tables                                 |
| [cube](cumulus_library_pcx/stage/cube.py)                               | [action](cumulus_library_pcx/cube.toml)                         | on            | patient-count cubes                                                             |

**Adding a stage**: write `stage/<name>.py` with `make_actions() -> list[Action]` and
`make() -> Path` (`save_actions_toml(make_actions(), '<name>.toml')`), then insert
`Stage(<name>)` into `STAGES` at the position it must build in. To list a hand-written file
instead, insert `Stage('<name>.toml')` or `Stage('<name>.workflow')`, with
`skip_by_default=True` if it should not run under `--stage all`.

A stage declares its actions with the dataclasses in [tools/staging.py](cumulus_library_pcx/tools/staging.py);
[tools/manifest.py](cumulus_library_pcx/tools/toml_tool.py) owns every TOML detail.

| Class                             | TOML                                                                                                   |
|-----------------------------------|--------------------------------------------------------------------------------------------------------|
| `SqlAction(files, label)`         | `[[actions]]`, `type = "build:serial"`; `Path` entries are written as `athena/`, `custom/` or `../tests/athena/` |
| `SqlParallelAction(files, label)` | same, `type = "build:parallel"`                                                                        |
| `FileAction(files, label)`        | `[[actions]]`, `type = "build:parallel"`, paths written exactly as given (used to reference a `file_upload` workflow) |
| `ExportAction(tables, label)`     | `[[actions]]`, `type = "export:counts"` (or `export:flat`, `export:meta`), `tables` list               |
| `UploadWorkflow(csvs, prefix)`    | a whole `config_type = "file_upload"` workflow, one `[tables.<name>]` per CSV                          |
| `Stage(module \| filename)`       | one `[[stages.<name>]]` in `manifest.toml`                                                             |

`label` becomes the TOML `label` key (cumulus-library deprecated `description`); square brackets
are replaced with parentheses because the loader rejects them.

---
## Environment

| Variable                    | Default                                      | Meaning                                                                                     |
|-----------------------------|----------------------------------------------|---------------------------------------------------------------------------------------------|
| `ELASTIC_OUTPUT_DIR`        | `$CUMULUS_LIBRARY_DATA_PATH/elastic/output`  | Where `elastic_upload` looks for Elastic result CSVs. When neither variable is set the stage prints a notice and makes an empty `elastic_upload.toml`. |
| `CUMULUS_LIBRARY_DATA_PATH` | —                                            | Only used as the fallback above by `make-pcx`; `cumulus-library build` has its own requirements. |
| `CUMULUS_ENCOUNTER_REF`     | `encounter_ref_link`                         | Encounter linkage rendered into the templates (`encounter_ref` for FHIR reference only).   |
| `CUMULUS_CUBE_AS_VIEW`      | `0`                                          | `1` renders cubes as views instead of tables.                                               |
| `CUMULUS_CUBE_MIN_SUBJECTS` | `10`                                         | Minimum patients per cube cell.                                                             |

## Input

Sources that `make-pcx` reads. Edit these, never the outputs.

| Source                                                                                         | Used by                                   |
|------------------------------------------------------------------------------------------------|-------------------------------------------|
| `spreadsheet/include_*.csv`, `age_group.csv`                                                   | study_population (via a hand-written upload) |
| `spreadsheet/dx_*.csv`, `rx_*.csv`, `lab_*.csv`, `proc_*.csv`                                  | study_variable                            |
| `spreadsheet/casedef.csv`                                                                      | casedef (column names read from the header) |
| `spreadsheet/client_dictionary.csv`                                                            | client_views                              |
| `cumulus_library_pcx/template/*.sql` (Jinja)                                                   | every made stage                          |
| `tests/template/*.sql`                                                                         | qa_athena                                 |
| `cumulus_library_pcx/custom/*.sql`                                                             | eligible, outcome, client_views (hand-written SQL, referenced as `custom/`) |
| `spreadsheet/file_upload_population.toml`, `file_upload_casedef.toml`, `file_upload_client_views.toml` | hand-written upload workflows: they declare per-column `col_types`, which the generator does not |
| `cumulus_library_pcx/elastic_query.toml`, `nlp_*.workflow`                                     | hand-written stages, listed only          |
| `cumulus_library_pcx/llm/template/pcx__llm_*.sql.jinja`, `nlp_*_tasks.workflow` (task versions) | nlp_document_wide, nlp_clinical_wide |
| `cumulus_library_pcx/manifest.toml` → `study_prefix`                                           | read at import for the `pcx__` prefix     |

## Output

| Generated                                                    | By                                        |
|--------------------------------------------------------------|-------------------------------------------|
| `cumulus_library_pcx/athena/*.sql`                           | each made stage, from templates and CSVs  |
| `tests/athena/*.sql`                                         | qa_athena                                 |
| `cumulus_library_pcx/llm/athena/pcx__llm_*.sql`              | nlp_document_wide, nlp_clinical_wide |
| `cumulus_library_pcx/<stage>.toml`                           | each made stage                           |
| `spreadsheet/file_upload_study_variable.toml`                | study_variable (`UploadWorkflow`, all columns strings) |
| `$ELASTIC_OUTPUT_DIR/<date>/file_upload_elastic.toml`        | elastic_upload, when results exist        |
| `cumulus_library_pcx/manifest.toml`                          | the default (no-stage) run                |
| `tests/data/synthetic/*.csv` (tables, `synthetic__truth.csv`, `test-synthetic.csv`) | `test-synthetic`   |

## Code

- [tools/cli.py](cumulus_library_pcx/tools/cli.py): argument parser and the installed `make-pcx` command
- [tools/study_builder.py](cumulus_library_pcx/tools/study_builder.py): stage selection, `make_stages`, `make_manifest`, `make_study`, and the `cumulus-library build` wrapper
- [stage/manifest.py](cumulus_library_pcx/stage/manifest.py): `STAGES`, the build order
- [tools/staging.py](cumulus_library_pcx/tools/staging.py): `Stage`, the `Action` dataclasses, `UploadWorkflow`
- [tools/manifest.py](cumulus_library_pcx/tools/toml_tool.py): dataclasses → TOML (`save_actions_toml`, `save_upload_toml`, `save_manifest_toml`), study prefix
- [tools/filetool.py](cumulus_library_pcx/tools/filetool.py): project paths, spreadsheet listing, `csv_columns`
- [tests/synthetic.py](tests/synthetic.py): the `test-synthetic` generator (`make_tests_synthetic`, `main`), loaded by `cli.load_tests_synthetic`
- [tools/template.py](cumulus_library_pcx/tools/template.py): Jinja rendering into `athena/` and `tests/athena/`
- [tools/nlp_wide.py](cumulus_library_pcx/tools/nlp_wide.py): renders `llm/template/` against a `.workflow`'s tasks and deployments, shared by the two NLP wide stages
- [stage/*.py](cumulus_library_pcx/stage): one module per made stage, each with `make_actions()` and `make()`

## Known issues

- **The NLP wide stages render against a fixed deployment list** (`DEFAULT_DEPLOYMENTS` in
  `tools/nlp_wide.py`); there is no command-line way to choose NLP deployments yet.
- **`--build` only knows the venv's `cumulus-library`.** There is no option to point at another
  install, change `-s`/`-t`, or drop `--force-upload`.
- **Hand-written upload workflows are not checked** against the CSVs they name; a renamed
  `include_*.csv` is only caught by `cumulus-library build`.
- **`--list` does not mark hand-written stages.** Naming one on the command line prints a
  "nothing to make" notice and exits 0.
- **[README.md](README.md#build)** still documents `python3 -m cumulus_library_pcx.tools.study_builder`
  and describes `client_views` and `qa_athena` as unwired; `make-pcx` generates and lists both.
