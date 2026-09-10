# Eligible

Inclusion criteria
* Patient encounter history at least 365 days  
  * [include_utilization.csv](spreadsheet/include_utilization.csv)
* Patient <= 3 years before diagnosis and up to 5 years followup
  * [include_age_at_visit.csv](spreadsheet/include_age_at_visit.csv)
* Patient meets diagnostic criteria 
  * [diagnosis.py](cumulus_library_pcx/llm/models/diagnosis.py) FHIR _and/or_ 
  * [dx_medulloblastoma.csv](spreadsheet/dx_medulloblastoma.csv) LLM

* Patient meets medication criteria 
  * Methotrexate the "casual contrast" _and/or_
    * [rx_contrast_methotrexate.csv](spreadsheet/rx_contrast_methotrexate.csv) and/or
  * 1+ chemotherapy drug 
    * [rx_chemo_carboplatin.csv](spreadsheet/rx_chemo_carboplatin.csv)
    * [rx_chemo_cisplatin.csv](spreadsheet/rx_chemo_cisplatin.csv)
    * [rx_chemo_cyclophosphamide.csv](spreadsheet/rx_chemo_cyclophosphamide.csv)
    * [rx_chemo_etoposide.csv](spreadsheet/rx_chemo_etoposide.csv)
    * [rx_chemo_thiotepa.csv](spreadsheet/rx_chemo_thiotepa.csv)
    * [rx_chemo_vincristine.csv](spreadsheet/rx_chemo_vincristine.csv)


# Diagnosi