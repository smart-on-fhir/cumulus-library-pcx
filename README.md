## Medulloblastoma: cohort and outcome requirements

**Goal:** Enable cube creation across the Cumulus and CBTN networks to compare overall survival by age at diagnosis, medulloblastoma subtype, methotrexate exposure, and radiation exposure.

### 1. Cohort definition — structured data

- **Diagnosis:** Medulloblastoma.
- **T₀:** First recorded medulloblastoma diagnosis. 
- **Age at diagnosis:** Include all ages, with a toggle for **<36 months** versus **≥36 months**.

### 2. Cohort characteristics — NLP plus structured data where available

| Characteristic          | Required distinction                       | Extraction requirement                                                                              |
|-------------------------|--------------------------------------------|-----------------------------------------------------------------------------------------------------|
| Medulloblastoma subtype | Group 3 and other subtypes, selectable     | Capture subtype, supporting evidence, and unknown or conflicting results.                           |
| Methotrexate treatment  | Received versus not received, **any dose** | Identify actual administration and its date; distinguish planned treatment from treatment received. |
| Radiation treatment     | Received versus not received, **any dose** | Identify delivered radiation and its date; distinguish planned treatment from treatment received.   |

For both treatment variables, retain **unknown/not documented** separately from confirmed absence of treatment.

Use `spreadsheet/rx_agent_methotrexate.csv` as the single methotrexate valueset across
ingredients and formulations. It includes all codes formerly in the separate injectable
subset. Determine administration, route, dose, timing, and treatment phase from treatment
evidence. A valueset match alone does not establish receipt or high-dose intravenous therapy.

### 3. Primary summary measure — overall survival

- **Origin:** T₀.
- **Event:** Death, using `patient_deceased` or the corresponding vital-status field.
- **Event date:** Date of death.
- **Censoring date:** Last date documented alive for patients without a recorded death.
- **Required inputs:** Diagnosis date, vital status, death date when applicable, and last-known-alive date.

A deceased flag or last vital status alone is insufficient to calculate survival duration; associated dates are required.

### 4. Cross-network cube requirements

- Apply shared definitions and extraction rules across Cumulus and CBTN.
- Support filtering or stratification by network, age group, subtype, methotrexate exposure, and radiation exposure.
- Retain missingness and follow-up availability so Sarah can assess comparability.
- Resolve potential patient overlap before pooling network results.
- Define the treatment-exposure timing rule before comparing survival: grouping patients by treatment received at any later time can bias comparisons measured from diagnosis.

### 5. Reach goal — event-free survival (EFS)

Capture dated progression, relapse/recurrence, remission, and death records, with supporting evidence.

Before calculating EFS, agree on:

- Which events count as an EFS event.
- Whether the time origin is diagnosis or treatment initiation.
- How event-free follow-up and censoring are established.
- How conflicting or uncertain event dates are handled.

Remission should be captured as a disease-status transition; it should not automatically count as an adverse EFS event.

### Immediate next step

Create a shared data dictionary and assess field availability in both networks, then validate subtype and treatment extraction on a reviewed patient sample before generating comparative survival outputs.
