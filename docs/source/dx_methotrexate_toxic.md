# Methotrexate toxicity evidence tiers

Current repository status, 2026-09-11: [the valueset](spreadsheet/dx_methotrexate_toxic.csv) contains 30 rows (11 ICD-9-CM and 19 ICD-10-CM; 25 distinct system/code pairs). It is registered and represented in generated diagnosis and wide SQL. The boolean flag indicates any matching code, including Tier 4 monitoring/use evidence, not adjudicated toxicity. Its five wide columns (`dx_methotrexate_toxic`, `_category`, `_onset`, `_ref`, `_status`) are in the shared data dictionary. Nine rows are duplicate (system, code) pairs with different displays (909.5, 963.1, V58.69, V58.83), which `select distinct *` keeps as separate rows in `pcx__cohort_dx_methotrexate_toxic` and the wide dx table; Tier 4 is defined only in this file (workplan 5.6). The valueset is not read by the eligible or outcome SQL.

Study-specific review prioritization, not a validated causality score or toxicity severity grade. Tier 1 is strongest evidence in this file. Assign tiers using the ICD-9-CM code meaning, not the methotrexate-specific discovery display. Exact system/code joins cannot preserve the specificity of those display labels.

| Tier | Codes | Interpretation |
|---|---|---|
| 1 | 963.1, E933.1 | Poisoning by, or adverse effects of, antineoplastic and immunosuppressive drugs. Explicit drug-class harm evidence. Does not identify methotrexate specifically. |
| 2 | 909.5 | Late effect of a drug adverse effect. Drug unspecified. Does not establish a new or active toxicity event. |
| 3 | 584.5 | Acute kidney failure with tubular necrosis. Organ injury without coded drug attribution. Requires corroboration. |
| 4 | V58.69, V58.83 | Long-term medication use or therapeutic drug monitoring only. Context, not positive toxicity evidence. Exclude from toxicity case counts unless separately corroborated. |

All 11 input rows and their discovery displays are preserved. Duplicate system/code pairs receive the same tier. That initial ICD-9 tiering step added no codes; the subsequent ICD-10 expansion below added 19. None of these codes alone establishes methotrexate causality. Medication exposure, timing, and clinical documentation are needed for attribution. Poisoning and therapeutic-use adverse effects are distinct event types.

Sources checked 2026-09-09:
- https://seer.cancer.gov/tools/casefinding/case2013long.html
- https://www.aapc.com/codes/icd9-codes/E933.1
- https://www.ncbi.nlm.nih.gov/books/NBK169247/table/sb158.t3/?report=objectonly
- https://www.cms.gov/regulations-and-guidance/guidance/transmittals/2017downloads/r120msp.pdf
- https://archive.cdc.gov/www_cdc_gov/nchs/data/icd/icdp501.pdf
- https://icdlist.com/icd-9/V58.83


## ICD-10-CM counterparts added 2026-09-09

The CSV now includes 19 distinct ICD-10-CM rows in addition to the 11 preserved ICD-9-CM rows. System: `http://hl7.org/fhir/sid/icd-10-cm`. ICD-10 displays use code meanings rather than copying the methotrexate-specific discovery labels. This is a study valueset expansion across corresponding clinical concepts, not a patient-level automatic recoding or a claim of exact one-to-one GEM equivalence.

| ICD-9-CM | ICD-10-CM counterpart(s) | Tier |
|---|---|---|
| 584.5 | N17.0 | 3 |
| 909.5 | T50.905S | 2 |
| 963.1 | T45.1X1A/D/S, T45.1X2A/D/S, T45.1X3A/D/S, T45.1X4A/D/S | 1 |
| E933.1 | T45.1X5A/D/S | 1 |
| V58.69 | Z79.899 | 4 |
| V58.83 | Z51.81 | 4 |

A/D/S is shorthand in this documentation only. Every complete code is enumerated separately in the CSV for exact joins. A denotes initial encounter (active treatment), D subsequent encounter, and S sequela. These distinctions must not be treated as interchangeable episode dates. Tier measures specificity of drug-harm evidence, not recency: class-specific sequela codes remain Tier 1 but do not establish active toxicity.

963.1 does not encode intent. Its broad counterpart expansion covers accidental, intentional self-harm, assault, and undetermined poisoning. The display `Accidental methotrexate overdose` alone corresponds only to the accidental subset if that text is verified in an individual source record. Code-only matching also captures other intents. Underdosing codes (T45.1X6*) are excluded because they are not poisoning/adverse-effect counterparts. Z79.899 is the other-drug-therapy counterpart relevant to this study; opioid- or hypoglycemic-specific alternatives are not added. These codes still do not identify methotrexate specifically or establish medication-table/site presence.

Mapping and descriptor references:
- https://www.icd9data.com/2015/Volume1/800-999/960-979/963/963.1.htm
- https://www.cms.gov/files/document/icd2019-cm-tabular-list-disease-and-injuries-pdf.pdf
- https://www.icd9data.com/2015/Volume1/800-999/905-909/909/909.5.htm
- https://www.sanidad.gob.es/gl/estadEstudios/estadisticas/normalizacion/clasifEnferm/boletines/Codificacion_clinica_n40_14.pdf
- https://www.va.gov/vdl/documents/clinical/anticoagulation_management_tool/oramig.pdf
- https://www.icd9data.com/2015/Volume1/V01-V91/V50-V59/V58/V58.69.htm
- https://icdlist.com/icd-10/T45.1X3S
