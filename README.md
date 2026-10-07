# pcx

Embryonal brain tumors (all ages, encounters from 2008 with history), Cumulus table
prefix `pcx`, emulating the ACNS0334 trial population. A coded case definition (medulloblastoma,
ATRT, CNS embryonal, ETMR, pineoblastoma), chemotherapy, laboratory toxicity, craniotomy and
radiation variables, note samples, 14 LLM chart-review schemas with 23 projections, opt-in
eligibility, outcome, client-export and QA stages, and 17 count tables. NLP prerequisites
(note selectors, `HOME_INSTITUTION`) are listed in PROTOCOL.md section 5.

- [PROTOCOL.md](PROTOCOL.md): frame, population, variables, decisions and open questions.
- [MIGRATION.md](MIGRATION.md): what changed from the pre-builder study and how it was verified.
  The pre-builder (make-pcx) version is git tag `0.2-pre-study-builder`.
- [WORKPLAN.md](WORKPLAN.md): open tasks.
- [CHANGELOG.md](CHANGELOG.md): short history of changes.
- [release/make_data_release.py](release/make_data_release.py): builds the data-only PyPI
  package ([Release](#release)).

## Set up

cumulus-study-builder 0.5.0 is the git tag `v0.5.0`, not on PyPI: installing it needs SSH
read access to `comorbidity/cumulus-study-builder`.

```sh
python -m venv .venv && source .venv/bin/activate
python -m pip install -c requirements-tested.txt "git+ssh://git@github.com/comorbidity/cumulus-study-builder.git@v0.5.0"
python -m pip install -c requirements-tested.txt -e '.[test]'
cumulus-study skills sync         # agent skills into .agents/skills
cumulus-study build               # SQL, manifests and LLM schemas. Runs nothing in the warehouse
cumulus-study validate
python -m pytest -q
```

## Edit

Population and terminology inputs live in `spreadsheet/` ([README](spreadsheet/README.md)),
study SQL in `cumulus_library_pcx/sql/custom/`, template overrides in
`cumulus_library_pcx/sql/template/`, counts in `cumulus_library_pcx/counts.workflow`, stage
order in `cumulus_library_pcx/stage/manifest.py`, and the study prefix only in
`cumulus_library_pcx/manifest.toml`. Generated SQL, stage TOMLs, LLM schemas and summaries
are build outputs; never edit them.

NLP stages need `builder.nlp_deployments` in `cumulus-study.toml` and are opt-in.

## Run in the warehouse

After site review, `cumulus-library build --study-dir cumulus_library_pcx` in a configured
Cumulus environment.
Opt-in stages run only when named; local generation never runs NLP, exports or queries.

## Release

The PyPI package `cumulus-library-pcx` is data-only: the rendered SQL and data files of the
seven default stages without NLP, no Python code and no dependencies. Sites install it next
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
