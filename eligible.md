# Which patients eligible?

The [eligible.toml](cumulus_library_pcx/eligible.toml) stage attempts to distill the clinical trial criteria 
retrospectively from EHR data. As of Sept 2026, there are some differences noted here.

We attempt to implement the criteria defined in [PMC12833527](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/); 
while understanding we may not have all the criteria available in the first pass of this PCX study.  

## Inclusion criteria ☑️

### Encounter

Required

| file                                                           | criteria                                    | 
|----------------------------------------------------------------|---------------------------------------------|
| [include_utilization.csv](spreadsheet/include_utilization.csv) | Patient encounter history at least 365 days |

### Patient age

Required

| file                                                             | criteria                                             | 
|------------------------------------------------------------------|------------------------------------------------------|
| [include_age_at_visit.csv](spreadsheet/include_age_at_visit.csv) | <= 3 years before surgery and up to 5 years followup |

### Diagnosis

Required 

| file                                                         | criteria                             | 
|--------------------------------------------------------------|--------------------------------------|
| [diagnosis.py](cumulus_library_pcx/llm/models/diagnosis.py)  | LLM chart review confirmed diagnosis |
| [dx_medulloblastoma.csv](spreadsheet/dx_medulloblastoma.csv) | supporting evidence                  |

### Surgery

Optional but highly desired

| file                                                    | criteria                           | 
|---------------------------------------------------------|------------------------------------|
| [surgery.py](cumulus_library_pcx/llm/models/surgery.py) | LLM chart review confirmed surgery |
| [proc_craniotomy.csv](spreadsheet/proc_craniotomy.csv)  | supporting evidence                |

### Medication

Required: Chemotherapy `+/-` Methotrexate (MTX) as the "casual contrast".

* Simplest: all patients matching [diagnosis](#diagnosis) criteria are included;
* Broader: all patients matching [diagnosis](#diagnosis) and [surgery](#surgery) criteria are included;
* Stricter: view, all patients matching [diagnosis](#diagnosis) and [surgery](#surgery) criteria and 1+ chemotherapy;
* clinical trial view, strictest criteria and more (out of scope for current study implementation)

| file                                                                       | criteria                           | 
|----------------------------------------------------------------------------|------------------------------------|
| [rx_contrast_methotrexate.csv](spreadsheet/rx_contrast_methotrexate.csv)   | Methotrexate the "casual contrast" |
| [rx_chemo_carboplatin.csv](spreadsheet/rx_chemo_carboplatin.csv)           | chemo: carboplatin                 | 
| [rx_chemo_cisplatin.csv](spreadsheet/rx_chemo_cisplatin.csv)               | chemo: cisplatin                   |
| [rx_chemo_cyclophosphamide.csv](spreadsheet/rx_chemo_cyclophosphamide.csv) | chemo: cyclophosphamide            | 
| [rx_chemo_etoposide.csv](spreadsheet/rx_chemo_etoposide.csv)               | chemo: etoposide                   |
| [rx_chemo_thiotepa.csv](spreadsheet/rx_chemo_thiotepa.csv)                 | chemo: thiotepa                    |
| [rx_chemo_vincristine.csv](spreadsheet/rx_chemo_vincristine.csv)           | chemo: vincristine                 |

----

## Exclusion criteria 🚫

### ATRT Diagnosis
| file                                                        | criteria                        | 
|-------------------------------------------------------------|---------------------------------|
| [diagnosis.py](cumulus_library_pcx/llm/models/diagnosis.py) | LLM chart review confirmed ATRT |
| [dx_atrt.csv](spreadsheet/dx_atrt.csv)                      | supporting evidence             |

### Prior Chemotherapy
Exclude patients who received ([chemo](#medication)) before t=0

### Prior Radiation Therapy

| file                                                        | criteria                             | 
|-------------------------------------------------------------|--------------------------------------|
| [radiation.py](cumulus_library_pcx/llm/models/radiation.py) | LLM chart review confirmed radiation |
| [proc_radiation.csv](spreadsheet/proc_radiation.csv)        | supporting evidence                  |

---
## pcx__eligible ❓

| table                                                                                 | purpose                                       |
|---------------------------------------------------------------------------------------|-----------------------------------------------|
| [pcx__eligible.sql](cumulus_library_pcx/custom/pcx__eligible.sql)                     | inclusion/exclusion criteria intersection     |
| [pcx__eligible_dx.sql](cumulus_library_pcx/custom/pcx__eligible_dx.sql)               | did patient match diagnosis criteria?         |
| [pcx__eligible_rx.sql](cumulus_library_pcx/custom/pcx__eligible_rx.sql)               | did patient have 1+ chemo agent?              |
| [pcx__eligible_surgery.sql](cumulus_library_pcx/custom/pcx__eligible_surgery.sql)     | did patient have surgery < 36 months age?     |
| [pcx__eligible_radiation.sql](cumulus_library_pcx/custom/pcx__eligible_radiation.sql) | did patient have **prior** radiation therapy? |


 