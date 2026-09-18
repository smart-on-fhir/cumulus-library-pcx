# Stage and tool boundaries

Stages declare study inputs, table names, labels, and serial/parallel action order.
Reusable tools receive those choices as arguments and implement the mechanics.
Keep existing stage entry points as small adapters during gradual extraction.

The current extractions are:

- `llm_schema_json.py`: discover annotation models in a supplied Python package
  and save their JSON schemas. `llm_schema_csv.py`: create human-readable CSV
  review summaries with configurable omitted fields. `llm/create_schemas.py` and `llm/create_summary_csv.py` keep PCX package,
  filename, output-directory, and evidence-field defaults as small adapters.
- `variable_tool.py`: discover variable files, group FHIR aspects, and render cohort
  joins from explicit source/destination names and column metadata. Checkout adapters
  provide discovery, naming and generation defaults for all variable consumers.
  `stage/study_variable.py` only assembles actions (`make_stages`) and writes its
  manifests (`make`); `make_actions` remains an alias for compatibility.
- `qa_athena_tool.py`: discover SQL files in a supplied directory and render count summaries.
  QA, warning, and example group definitions remain in `stage/qa_athena.py`.
- `tests/tools/synthetic_io.py` (test code, outside this package): load fixtures using a supplied schema, execute supplied SQL,
  and export CSVs. It imports DuckDB only when a database is requested.
  PCX distributions, clinical simulation, calibration, and CLI defaults remain
  in `tests/synthetic.py`; the generator is still a repository test utility.

Core helpers accept paths and table names from their callers. Variable checkout
adapters use `filetool` and `tablespace` defaults; callers can still use the core
helpers with explicit inputs for another study. Tests exercise them with another
study's table names and temporary directories. The DuckDB compatibility macros
cover current queries; they are not a general guarantee of Athena equivalence.
