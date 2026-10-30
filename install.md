# Installing and running PCX

How a site (CHOP) installs or upgrades the `cumulus-library-pcx` study package and runs it
from start to finish. The study prefix is `pcx`, so every command targets `-t pcx`.

## Pre-requirements

- Python 3.11 or newer.
- [cumulus-library](https://github.com/smart-on-fhir/cumulus-library), with the `core` study
  built. `pip install cumulus-library-pcx` brings the version PCX needs (6.3.7 or newer, below 6.4).
- [RxNorm](https://github.com/smart-on-fhir/cumulus-library-rxnorm), built.
- [LOINC](https://github.com/smart-on-fhir/cumulus-library-loinc), built.
- A working Athena connection for `cumulus-library`, by environment variables
  (`CUMULUS_LIBRARY_DATABASE`, `CUMULUS_LIBRARY_WORKGROUP`, `CUMULUS_LIBRARY_PROFILE`,
  `CUMULUS_LIBRARY_REGION`) or the matching flags (`--database`, `--workgroup`, `--profile`,
  `--region`).
- For the LLM stages: AWS Bedrock access to `gpt-oss-120b`, the Cumulus ETL folder of clinical
  notes (DiagnosticReport and DocumentReference), and the Cumulus ETL PHI folder.

## 1. First-time install

```sh
pip install cumulus-library-pcx
```

## 2. Upgrade

Remove the prior PCX tables, then replace the package.

```sh
cumulus-library clean --target pcx
pip uninstall -y cumulus-library-pcx
pip install cumulus-library-pcx
```

## 3. Build, start to finish

Run the steps in order. Each opt-in stage runs only when named with `--stage`, and each one
reads the tables built by the steps before it.

**3.1 Default stages.** Study population, coded variables, case definition, an empty
`pcx__elastic_union` (CHOP has no Elasticsearch export), the note sample `pcx__sample_task`,
the `counts` cubes and the study metadata.

```sh
cumulus-library build -t pcx
```

**3.2 LLM document tasks.** `document_type` and `document_topic` over the notes in
`pcx__sample_task`. Replace the two folders with your ETL's (an `s3://` URL or a local path).

```sh
cumulus-library build -t pcx --stage nlp_document_tasks \
  --nlp-provider bedrock --nlp-model gpt-oss-120b \
  --note-dir s3://YOUR-BUCKET/NOTES-FOLDER \
  --etl-phi-dir s3://YOUR-BUCKET/PHI-FOLDER
```

**3.3 Document results to SQL.** The document wide tables, and the note-selection tables
`pcx__llm_document_task_<task>` that the clinical tasks read.

```sh
cumulus-library build -t pcx --stage llm_document_wide
```

**3.4 LLM clinical tasks.** Diagnosis, surgery, radiation, systemic therapy and the other
clinical tasks, each over the notes the document tasks marked relevant to it.

```sh
cumulus-library build -t pcx --stage nlp_clinical_tasks \
  --nlp-provider bedrock --nlp-model gpt-oss-120b \
  --note-dir s3://YOUR-BUCKET/NOTES-FOLDER \
  --etl-phi-dir s3://YOUR-BUCKET/PHI-FOLDER
```

**3.5 Clinical results to SQL.** The `pcx__llm_*` wide tables.

```sh
cumulus-library build -t pcx --stage llm_clinical_wide
```

**3.6 Eligibility.** `pcx__eligible` (relaxed) and `pcx__eligible_trial` (strict ACNS0334).

```sh
cumulus-library build -t pcx --stage eligible
```

**3.7 Outcomes.** Vital status, first event, OS and EFS.

```sh
cumulus-library build -t pcx --stage outcome
```

**3.8 Client tables.** The `pcx__client_*` timeline and survival tables.

```sh
cumulus-library build -t pcx --stage client_views
```

**3.9 Quality checks (optional).** `pcx__qa_*` tables should have 0 rows. Rows in
`pcx__warn_*` tables are findings to look at.

```sh
cumulus-library build -t pcx --stage qa_athena
```

**3.10 Kaplan-Meier cubes.** OS and EFS cubes for all subjects and the strict cohort.

```sh
cumulus-library build -t pcx --stage counts_kaplan
```

## 4. Export and upload

Export the Kaplan-Meier cubes and the study metadata to a folder, then upload that folder to
the Cumulus aggregator. Use an empty folder so nothing else is uploaded with them.

```sh
cumulus-library export -t pcx --stage counts_kaplan ./pcx-export
```

```sh
cumulus-library upload -t pcx ./pcx-export --user YOUR-AGGREGATOR-USER --id YOUR-SITE-ID
```

- The folder can also come from `CUMULUS_LIBRARY_DATA_PATH`.
- `--user` and `--id` can come from `CUMULUS_AGGREGATOR_USER` and `CUMULUS_AGGREGATOR_ID`.
  Ask the aggregator administrator for these, and for `--url` and `--network` if needed.
- `--preview` prepares the upload and prints it without sending anything.
- The general `counts` cubes (from step 3.1) are not part of this export. Export them with
  `--stage counts` only when you have agreed to upload them.
