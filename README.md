# pcx

Pediatric embryonal brain tumors (ages 0-8, encounters from 2008 with history), Cumulus table
prefix `pcx`, emulating the ACNS0334 trial population. A coded case definition (medulloblastoma,
ATRT, CNS embryonal, ETMR, pineoblastoma), chemotherapy, laboratory toxicity, craniotomy and
radiation variables, note samples, 14 LLM chart-review schemas with 23 projections, opt-in
eligibility, outcome, client-export and QA stages, and 17 count tables. NLP prerequisites
(note selectors, `HOME_INSTITUTION`) are listed in PROTOCOL.md section 5.

- [PROTOCOL.md](PROTOCOL.md): frame, population, variables, decisions and open questions.
- [MIGRATION.md](MIGRATION.md): what changed from the pre-builder study and how it was verified.
- [WORKPLAN.md](WORKPLAN.md): open tasks from the 2026-09-21 review
  ([README-sept-21.md](README-sept-21.md)) and what is already done.
- [CODE_REVIEW.md](CODE_REVIEW.md): 2026-09-19 review findings; open items are tracked in WORKPLAN.md.
- [CHANGELOG.md](CHANGELOG.md): short history of changes.

## Set up

cumulus-study-builder 0.4.1 is not published yet. Install the wheel kept in the parent
`baseline/dist` directory (adjust the path for an independent fork).

```sh
python -m venv .venv && source .venv/bin/activate
python -m pip install -c requirements-tested.txt ../baseline/dist/cumulus_study_builder-0.4.1-py3-none-any.whl
python -m pip install -c requirements-tested.txt -e '.[test]'
cumulus-study skills sync         # agent skills into .agents/skills
cumulus-study validate
cumulus-study build               # SQL, manifests and LLM schemas. Runs nothing in the warehouse
python -m pytest -q
```

## Edit

Population and terminology inputs live in `spreadsheet/` ([README](spreadsheet/README.md)),
study SQL in `study/sql/custom/`, template overrides in `study/sql/template/`, stage order in
`study/stage/manifest.py`, and the study prefix only in `study/manifest.toml`. Generated SQL,
stage TOMLs, LLM schemas and summaries are build outputs; never edit them.

NLP stages need `builder.nlp_deployments` in `cumulus-study.toml` and are opt-in.
The optional biostats scaffold (`analysis/`, `study/stage/biostats.py`) is commented out
in the stage manifest; see [analysis/README.md](analysis/README.md).

## Run in the warehouse

After site review, `cumulus-library build -s ./study` in a configured Cumulus environment.
Opt-in stages run only when named; local generation never runs NLP, exports or queries.
