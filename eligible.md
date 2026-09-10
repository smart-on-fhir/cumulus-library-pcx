# Which patients eligible? 

## Inclusion criteria

### Encounter

| file                                                           | criteria                                    | 
|----------------------------------------------------------------|---------------------------------------------|
| [include_utilization.csv](spreadsheet/include_utilization.csv) | Patient encounter history at least 365 days |

### Patient age 

| file                                                           | criteria                                    | 
|----------------------------------------------------------------|---------------------------------------------|
| [include_age_at_visit.csv](spreadsheet/include_age_at_visit.csv) | <= 3 years before diagnosis and up to 5 years followup |

### Diagnosis 

| file                                                         | criteria                                             | 
|--------------------------------------------------------------|------------------------------------------------------|
| [diagnosis.py](cumulus_library_pcx/llm/models/diagnosis.py)  | LLM chart review confirmed Medulloblastoma diagnosis |
| [dx_medulloblastoma.csv](spreadsheet/dx_medulloblastoma.csv) | supporting evidence                                  |


### Medication

Methotrexate +/- one of the chemotherapuetic agents. 
The inclusion of one or more chemo agents is desired but not **strictly** required.     

| file                                                                       | criteria                           | 
|----------------------------------------------------------------------------|------------------------------------|
| [rx_contrast_methotrexate.csv](spreadsheet/rx_contrast_methotrexate.csv)   | Methotrexate the "casual contrast" |
| [rx_chemo_carboplatin.csv](spreadsheet/rx_chemo_carboplatin.csv)           | chemo: carboplatin                 | 
| [rx_chemo_cisplatin.csv](spreadsheet/rx_chemo_cisplatin.csv)               | chemo: cisplatin                   |
| [rx_chemo_cyclophosphamide.csv](spreadsheet/rx_chemo_cyclophosphamide.csv) | chemo: cyclophosphamide            | 
| [rx_chemo_etoposide.csv](spreadsheet/rx_chemo_etoposide.csv)               | chemo: etoposide                   |
| [rx_chemo_thiotepa.csv](spreadsheet/rx_chemo_thiotepa.csv)                 | chemo: thiotepa                    |
| [rx_chemo_vincristine.csv](spreadsheet/rx_chemo_vincristine.csv)           | chemo: vincristine                 |

## Steps 
1. Encounter criteria 
2. Diagnosis criteria 
3. Medication criteria

## TODO 

* radiation relative to t=0 (diagnosis)
* surgery relative to t=0 (diagnosis)


 