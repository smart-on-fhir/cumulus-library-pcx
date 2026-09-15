# PCX Laboratory data

Lab test results are useful for the strictest trial matching scenarios;
broadly speaking these are not inclusion/exclusion criteria per se but they are helpful supporting evidence.
ACNS0334 required adequate marrow, liver and kidney function at enrollment; the LLM
[registry_eligibility](cumulus_library_pcx/llm/models/registry_eligibility.py) and
[laboratory](cumulus_library_pcx/llm/models/laboratory.py) tasks capture that from notes.

Each CSV becomes `pcx__cohort_<name>` through the study_variable stage and a boolean column of the same name in
`pcx__cohort_variable_wide`. No eligible or outcome SQL reads a lab table yet; `pcx__client_encounter.lab_organ_function_bool`
flags encounters with any of the seven organ-function labs.

| Laboratory valueset                                                                 | Entries | Current scope or open issue                                                    |
|-------------------------------------------------------------------------------------|--------:|--------------------------------------------------------------------------------|
| [Absolute neutrophil count](spreadsheet/lab_absolute_neutrophil_count.csv)          |       2 | 751-8 and 26499-4; the manual-count LOINC 753-4 is missing (workplan 5.8)       |
| [ALT](spreadsheet/lab_alt.csv)                                                      |       9 | Five LOINCs and four local codes                                               |
| [AST](spreadsheet/lab_ast.csv)                                                      |       6 | Three LOINCs and three local codes                                             |
| [Creatinine](spreadsheet/lab_creatinine.csv)                                        |       8 | One LOINC and seven local candidates; proposed additional LOINCs not yet added |
| [Hemoglobin](spreadsheet/lab_hemoglobin.csv)                                        |      33 | Includes reticulocyte hemoglobin code 923, which remains a scope concern       |
| [Platelets](spreadsheet/lab_platelets.csv)                                          |       9 | Includes manual, optical, estimated and EDTA-context counts                    |
| [Total bilirubin](spreadsheet/lab_total_bilirubin.csv)                              |       1 | 1975-2 only; 42719-5 and 14631-6 are missing (workplan 5.8)                     |

Folate valuesets were removed from the study on 2026-09-14. The seven organ-function
valuesets above remain. Two generated files with no CSV and no toml entry,
`athena/pcx__cohort_lab_albumin.sql` and `athena/pcx__cohort_lab_platelet_count.sql`, are stale leftovers (workplan 5.1).
Methotrexate serum levels (LOINC 3618-4, 14836-1) and leucovorin, the strongest structured markers of high-dose
methotrexate, have no valueset yet (workplan 3.7).
