# pcx

Embryonal brain tumors (all ages, encounters from 2008 with history), Cumulus table
prefix `pcx`, emulating the ACNS0334 trial population. A coded case definition (medulloblastoma,
ATRT, CNS embryonal, ETMR, pineoblastoma), chemotherapy, laboratory toxicity, craniotomy and
radiation variables, note samples, 14 LLM chart-review schemas with 23 projections, opt-in
eligibility, outcome, client-export and QA stages, and 17 count tables.

## Study

- [PROTOCOL.md](PROTOCOL.md): frame, population, variables, decisions and open questions.
- [eligible.md](eligible.md): eligibility criteria and how each is computed.
- [laboratory.md](laboratory.md): the toxicity laboratory valuesets.
- [LLM.md](LLM.md): the LLM extraction models, note selection, schemas and wide tables.
- [limitations.md](limitations.md): scientific gaps between ACNS0334 and the EHR emulation.

## Build and release

- [cumulus-study.md](cumulus-study.md): set up, commands, stages, settings, running in the
  warehouse, and the data-only PyPI release.
- [rapid-elastic.md](rapid-elastic.md): the Elasticsearch query topics and how their results are loaded.
- [spreadsheet/README.md](spreadsheet/README.md): the population and terminology inputs.

## Status

- [WORKPLAN.md](WORKPLAN.md): open tasks.
- [changelog.md](changelog.md): short history of changes.
- [MIGRATION.md](MIGRATION.md): what changed from the pre-builder study. The pre-builder
  (make-pcx) version is git tag `0.2-pre-study-builder`.

## Older notes

In `docs/source/`, not yet reviewed against the current code:
[deferred.md](docs/source/deferred.md), [synthetic.md](docs/source/synthetic.md),
[README-0.2.md](docs/source/README-0.2.md).
