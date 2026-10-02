# Analysis exports

PCX flat client exports come from the opt-in `client_views` stage (`study/sql/custom/client_views/`,
dictionary `spreadsheet/client_dictionary.csv`); those contracts are unchanged.

## Optional biostats scaffold (from cumulus-study-template)

Record the requested scope in `PROTOCOL.md` section 8: no biostats, exports only, or selected
IPTW, Cox PH and Kaplan–Meier methods. `Stage(biostats)` is commented out in
`study/stage/manifest.py` until the demonstration SQL and export contract are replaced by the
protocol's analysis rows.

| File | Purpose |
|---|---|
| `study/sql/custom/biostats/analysis.sql` | Assemble analysis rows from eligible and outcome tables (demonstration SQL; replace). |
| `study/stage/biostats.py` | Declare SQL order and named `export:flat` tables. |
| `analysis/exports.toml` | Exported column names, types, nullability and primary keys (demonstration; replace). |
| `analysis/biostats.toml` | Statistical roles and methods; create only when modeling is requested. |
| `study/biostats.toml` | Generated stage manifest; never edit. |

After the flat tables are exported from the warehouse:

```sh
cumulus-study prepare --input-dir /path/to/exported/csv --output-dir analysis/output/prepared/run-001
```

To fit models, when requested, install the extra and author `analysis/biostats.toml` with the
biostats skill (`.agents/skills/biostats/references/analysis.md` is the version-1 contract):

```sh
pip install -e '.[biostats]'
cumulus-study analyze validate --input-dir analysis/output/prepared/run-001
cumulus-study analyze run --input-dir analysis/output/prepared/run-001 --output-dir analysis/output/results/run-001
```

Building SQL never runs models. Keep exports, prepared data and results under the ignored
`analysis/input/` and `analysis/output/` paths.
