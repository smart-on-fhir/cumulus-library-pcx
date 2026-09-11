# PCX LLM outputs

Builder integration updated 2026-09-11. Annotation class names no longer carry the `Pcx` prefix; builder and table names retain it. Shared mention/date validation is warn-only by default; see [validation settings](llm.md). The wide projection preserves values and does not repair invalid dates or adjudicate conflicting sources.

`create_schema.py` generates JSON schemas for the 14 clinical extraction tasks
and the two document classification/routing tasks. From the repository root:

```sh
python -m cumulus_library_pcx.llm.create_schema
```

Schemas are written under `cumulus_library_pcx/llm/schemas/`; this command does not run extraction.

## Diagnosis wide table

`cumulus_library_pcx/llm/builder/pcx_diagnosis_wide.py` creates
`pcx__llm_diagnosis_wide`. The active `nlp_clinical_tasks_wide` manifest invokes
eight Python builders: diagnosis, systemic-therapy regimen and agent, surgery,
radiation, patient vital status and anchors, and events. Clinical NLP inference
remains a separate, commented-out stage. The builders expect already-imported,
structured NLP tables. Default diagnosis sources are:

- `pcx__nlp_diagnosis_claude_sonnet45`
- `pcx__nlp_diagnosis_gpt51`
- `pcx__nlp_diagnosis_gpt54`
- `pcx__nlp_diagnosis_gpt_oss_120b`

Deployment suffixes are defined in `tools/settings.py`. Override them before
starting a build with `CUMULUS_PCX_NLP_DEPLOYMENTS=site_a,site_b`. An explicitly
empty value disables source discovery. Suffixes must contain only letters,
digits, or underscores. NLP builders do not require an Elastic export directory.

Tables must contain
`note_ref`, `encounter_ref`, `subject_ref`, `generated_on`, `task_version`,
`system_fingerprint`, and a structured `result` matching `DiagnosisAnnotation`.
Discovery checks every nested field in the task's Pydantic schema, including
nullable fields and fields within arrays, using Cumulus's schema parser. It also
checks the source metadata columns and requires a non-null result for the current
task version. Clinical versions come from `nlp_clinical_tasks.toml`; document
versions come from `nlp_doc_type_tasks.toml`. Mixed-version tables contribute only
the configured version. Missing tables, incompatible structures, stale-only
tables, and empty/null-only results are skipped, with reasons in the builder's
INFO logs. Failures of the version-row query propagate.

This is field-presence and version validation, not scalar-type validation or
execution of the models' custom clinical validators. Incompatible source schemas
require migration or re-extraction; a row-version filter cannot repair them.

Diagnosis task version 2 in the current configuration returns seven mentions:
disease subtype (including historical diagnosis wording), medulloblastoma
histology, primary-site wording, Chang M-stage, age at diagnosis, diagnosis date,
and confirmatory tissue-diagnosis date. Mentions retain evidence spans in the
source NLP results. The wide table projects ten clinical values plus seven source
metadata columns, omitting spans and mention flags. Integrated-diagnosis wording
is deferred as low-priority validation work in [deferred work](deferred.md).

Diagnosis fields retain their source types: the expected schema uses BIGINT for
age and VARCHAR for other values, including diagnosis dates. Only generated_on and task_version are
cast (to VARCHAR and BIGINT respectively) to normalize deployment metadata and
match the empty-table schema. Coarse dates retain their MONTH/YEAR precision; do not interpret their
first-of-period placeholders as exact dates. Unknown values remain unchanged.

The template receives its task version from the workflow configuration (currently
2 for diagnosis), rather than embedding a fixed version.
Source tables must match the current mention structure, with historical terms
under disease_subtype. Older output needs explicit conversion or re-extraction;
a row filter alone cannot change the source table's result structure. With no
qualifying sources, the builder creates an empty table with matching columns/types.
An empty output means no usable source results; it does not establish clinical absence.

`cumulus_library_pcx/llm/template/pcx__llm_diagnosis_wide.sql.jinja` drives the builder.
`cumulus_library_pcx/llm/athena/*.sql` are rendered regression snapshots for a
fixed GPT-OSS fixture, not manifest build inputs. Regenerate all 23 snapshots after
template or task-version changes with:

```sh
python -m cumulus_library_pcx.llm.render_snapshots
```

Use `--output-dir PATH` to render a separate review copy. This command renders
SQL only; it does not discover database tables or run queries.

Local regression tests execute generated SQL against synthetic DuckDB records,
including verbatim wording, partial dates, multiple sources/versions, and the empty-table
fallback. The discovery suite uses the installed Cumulus schema parser, its NLP
export schema for all eight active projections, and its Python builder loader.
It also compares all 23 snapshots with their current templates and task versions.
Athena execution requires separate validation; the previously identified nested
`UNNEST` issue is not resolved by switching the manifest to builders.

The inactive compact medulloblastoma model also has a separate export limitation:
the installed Cumulus 6.3.1 NLP serializer rejects its `datetime.date` fields.
Its snapshot can be rendered, but that does not establish an executable inference path.
