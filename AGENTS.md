# Study repository

Start every session by reading [PROTOCOL.md](PROTOCOL.md). If it has no `[decided]` lines or has `[open]` items, use
the `study-builder` skill: it takes a trial document, a PubMed article, a methods section
or nothing, then interviews the researcher stage by stage and records decisions there.

This repository owns study inputs, models, SQL, tests and stage order. Shared tools come
from the installed `cumulus-study-builder`. Do not copy builder code into the study.
Read [cumulus-study.toml](cumulus-study.toml), the study package's `manifest.toml` and `stage/manifest.py`.
Skills live in `.agents/skills` (`cumulus-study skills sync`, `cumulus-study skills check`).
Your own skill folders there are kept by sync.

Clinical definitions come from the researcher. Shipped synthetic codes and example
eligibility and outcome SQL are placeholders. Proposed codes are candidates until verified.
Keep absence, negation and missing documentation distinct.

Edit CSVs, models and SQL sources, then `cumulus-study validate`, `cumulus-study build`,
`python -m pytest`. Never edit generated SQL, schemas or stage TOMLs. Local generation
does not authorize warehouse execution or LLM inference. Keep patient data and
credentials out of the repository.

Study-specific agent instructions live in the `Agent rules` section at the end of
`PROTOCOL.md`. Add local rules there, not here: this file is managed by the builder starter.
