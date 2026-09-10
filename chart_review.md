# PCX LLM outputs

Checked 2026-09-10. Annotation class names no longer carry the `Pcx` prefix; builder and table names retain it. Shared mention/date validation is warn-only by default; see [validation settings](llm.md). The wide projection preserves values and does not repair invalid dates or adjudicate conflicting sources.

`create_schema.py` generates JSON schemas for the 14 clinical extraction tasks
and the two document classification/routing tasks. From the repository root:

```sh
python -m cumulus_library_pcx.llm.create_schema
```

Schemas are written under `cumulus_library_pcx/llm/schemas/`; this command does not run extraction.

## Diagnosis wide table

`cumulus_library_pcx/llm/builder/pcx_diagnosis_wide.py` creates
`pcx__llm_diagnosis_wide`. It is not currently registered in the main manifest;
the former `llm_output` stage and `llm/output.toml` are absent. The clinical NLP
stage is also commented out. The builder expects already-imported, structured
NLP tables:

- `pcx__nlp_diagnosis_claude_sonnet45`
- `pcx__nlp_diagnosis_gpt51`
- `pcx__nlp_diagnosis_gpt54`
- `pcx__nlp_diagnosis_gpt_oss_120b`

These deployment suffixes are inherited from the copied builder; adjust the list
in `pcx_base_mixin.py` if your imported table names differ. Tables must contain
`note_ref`, `encounter_ref`, `subject_ref`, `generated_on`, `task_version`,
`system_fingerprint`, and a structured `result` matching `DiagnosisAnnotation`.
The discovery check verifies the result column, not model-version compatibility.
Incompatible result schemas need migration before combining them.

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

The SQL selects task_version = 2, matching the current diagnosis configuration.
Source tables must match the current mention structure, with historical terms
under disease_subtype. Older output needs explicit conversion or re-extraction;
a row filter alone cannot change the source table's result structure. With no
available sources, the builder creates an empty table with matching columns/types.

`cumulus_library_pcx/llm/template/pcx__llm_diagnosis_wide.sql.jinja` drives the builder.
`cumulus_library_pcx/llm/athena/pcx__llm_diagnosis_wide.sql` is its standalone Athena example for the
GPT-OSS source only. Use the builder to combine available deployments; do not run
both creation routes against an existing destination without your normal rebuild
procedure.

Local regression tests execute generated SQL against synthetic DuckDB records,
including verbatim wording, partial dates, multiple sources/versions, and the empty-table
fallback. Athena execution requires validation in your own environment.
