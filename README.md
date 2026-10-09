# pcx

Embryonal brain tumors (no age restriction, encounters from 2008 with history), Cumulus table
prefix `pcx`, emulating the ACNS0334 trial. The trial enrolled young children; this
study population has no age limit, and age is an eligibility flag. A coded case definition (medulloblastoma,
ATRT, CNS embryonal, ETMR, pineoblastoma), chemotherapy, laboratory toxicity, craniotomy and
radiation variables, note samples, LLM chart-review tasks with their wide tables, opt-in
eligibility, outcome, client-export and QA stages, and count tables.

This is a retrospective, proof-of-concept emulation of
[ACNS0334](https://clinicaltrials.gov/study/NCT00336024)
([PMC12833527](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527)). Not every trial
eligibility criterion is met in this phase ([limitations.md](limitations.md)).

## Study

- [PROTOCOL.md](PROTOCOL.md): frame, population, variables, decisions and open questions.
- [eligible.md](eligible.md): eligibility criteria and how each is computed.
- [laboratory.md](laboratory.md): the toxicity laboratory valuesets.
- [llm.md](llm.md): the LLM extraction models, note selection, schemas and wide tables.
- [limitations.md](limitations.md): scientific gaps between ACNS0334 and the EHR emulation.

## Build and release

- [cumulus-study.md](cumulus-study.md): set up, commands, stages, settings, running in the
  warehouse, site requirements, the table glossary, and the data-only PyPI release.
- [rapid-elastic.md](rapid-elastic.md): the Elasticsearch query topics and how their results are loaded.
- [spreadsheet/README.md](spreadsheet/README.md): the population and terminology inputs.

## Status

- [WORKPLAN.md](WORKPLAN.md): open tasks, then the changelog.
- The pre-builder (make-pcx) version is git tag `0.2-pre-study-builder`.
