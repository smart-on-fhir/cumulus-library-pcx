# tests/synthetic.py (`make-pcx test-synthetic`)

Generator that simulates a real-world-like cohort and exports the 10 eligible/outcome tables as Athena-style CSV
(`SELECT * FROM pcx__<table>` download format: all values quoted, NULL empty, booleans true/false).

    make-pcx test-synthetic [--patients 1000] [--seed 334] [--noise 1.0] [--no-utilization-screen] [--quiet]
        regenerates tests/data/synthetic (derived, synthetic__truth.csv and upstream tables in one directory,
        plus test-synthetic.csv, the report as records), removing stale CSVs first
    python tests/synthetic.py OUTPUT_DIR [same options] [--include-inputs]
        the same generator aimed at any directory (test code, deliberately outside cumulus_library_pcx/)

## Design
1. Latent truth per patient (tumor, molecular group, age, M-stage, resection, MTX, RT, relapse, death, follow-up).
2. Emits the upstream tables in tests/data/schema.sql (casedef, encounters, orders, procedures, LLM wide tables).
3. Runs the REAL custom/pcx__*.sql in DuckDB in the order eligible.toml + outcome.toml list them, so derived tables
   cannot drift from the SQL. `date_diff` is overridden with `datesub` so month ages are Athena completed months.
4. Exports derived tables + `synthetic__truth.csv` (latent truth per subject). `--include-inputs` keeps the upstream
   tables beside them, so `tests/sqltest.py connect(data_dir)` can load the directory in place of tests/data/warn
   (it loads only schema.sql tables, ignoring the derived CSVs).
Casedef codes are read from spreadsheet/casedef.csv at run time. Refuses to write into tests/data/warn (fixtures p1-p8).

## Population
- Output = CSV as if selected out of Athena. Population = patients <= 3 years old (under 48 months at presentation,
  so 36-47 month olds exercise the under-36-months criterion). MTX effect = paper effect + confounding by indication.
  Noise = realistic and tunable (`--noise`, 0 = clean).

## Calibration to ACNS0334 (PMC12833527)
- Tumor mix MB .55 / ETMR .11 / pineo .08 / other .11 / ATRT .15; MB groups G3 .64, SHH .25, G4 .08, WNT .03.
- Table 1: M-stage, extent of resection, histology, sex, age (median ~23 months in the trial-like cohort).
- Latent 5y EFS: G3 33% without vs ~68% with MTX (planted log-odds 1.60), SHH ~93%, ETMR ~27%, pineo ~7%, no MTX
  benefit outside MB/ATRT. Relapses within 22 months (3% late), 4% toxic death, salvage RT 55% of relapses.
- MTX confounded by metastatic, anaplastic, era >= 2016, age < 8 months: naive contrast understates the benefit.

## Findings worth knowing
- The utilization screen (2+ encounters, 365+ days) removes ~18% of simulated patients, mostly early deaths:
  derived KM 5y EFS for trial-like MB is ~78% vs 62% with the screen, ~73% vs 51% with `--no-utilization-screen`
  (paper 68% vs 46%). Quantifies limitations.md / workplan 2.7.
- ETMR / pineoblastoma / cns_embryonal subjects get NULL t0 and NULL os_days today (workplan 2.5), ~30% of rows.
- pcx__eligible_trial is ~30% of pcx__eligible at noise 1, ~46% at noise 0. Main losses: NULL no_prior_radiation
  (no RT evidence and no EXPLICITLY_NOT_RECEIVED note), MONTH-precision LLM chemo dates landing before t0, transfers.
- All pcx__warn_* tables fire at plausible rates; both pcx__qa_* tables stay at 0.