# Limitations and gaps for reproducing ACNS0334 in EHR data

The scientific goal is to assess whether the treatment-associated outcome differences
observed in ACNS0334 are also observed in comparable EHR-derived medulloblastoma
cohorts, prioritizing Group 3.

The repository now defines a discovery cohort, a trial-like cohort, dated vital status, OS and a
provisional EFS ([eligible.md](eligible.md), [README](README.md)). It does not yet specify an
observational treatment-effect analysis. The scientific items below remain gaps with proposed
resolutions. The implementation findings were checked against the files on 2026-09-11; no patient
data or completed cross-network analysis was audited. The ordered fix list is [workplan.md](workplan.md).

## Current implementation findings (2026-09-11)

- The build does not run. `manifest.toml` wires the `.workflow` NLP configs as submanifests, which cumulus-library 6.3.1 rejects at parse time; `elastic_output.toml` references an upload manifest outside the repository; `tools/settings.py` fails at import without `CUMULUS_LIBRARY_DATA_PATH`; the wide-table templates render `AND task_version =`; and on Athena the tiered study-variable valuesets are uploaded as strings, so `tier = 1` is `varchar = integer`. Details in [reviews/code-review-2026-09-11/REVIEW.md](reviews/code-review-2026-09-11/REVIEW.md), fixes in workplan phase 1.
- The active manifest runs population, variable, wide-variable, case-definition, sample, wide-LLM, eligible and outcome stages. The 50k NLP stages and elastic output are registered with `skip_by_default` (ignored on a submanifest stage). Query, full NLP, QA and cube stages are commented out. Client views are generated but not wired.
- The test suite is 72 passed, 40 failed, 1 collection error. The 47 structured SQL tests pass on DuckDB; the LLM builder tests specify a deployment-discovery design that is not implemented. DuckDB does not reproduce three Athena behaviours the SQL depends on: month arithmetic, `varchar = integer`, and `DATE(varchar)` on a full timestamp.
- The population SQL applies ages 0–8 at visits, not all ages at diagnosis. It also requires at least two distinct encounter-period ordinals and a minimum 365-day observed encounter span. This filter is not censoring and can remove early deaths or short follow-up. Survival analyses should not inherit this restriction without a justified selection design (workplan 2.7).
- Time zero is the first study-population encounter with a tier 1 medulloblastoma casedef code. The casedef stage keeps a second anchor (first casedef encounter of any tier or subtype) for note sampling, so a subject can have two time zeros. The Condition's own onset and recorded dates are not consulted. Subjects whose only tier 1 evidence is an sPNET subtype, or an ICD-O-3 morphology code (absent from casedef.csv), never get a time zero.
- Three eligible-stage defects change the trial-like cohort: a NULL time zero turns the two prior-therapy exclusions into TRUE; the trial view requires positive radiation and chemotherapy evidence rather than absence of prior evidence, which selects on post-baseline treatment; and SNOMED 428061005 is tier 1 ATRT in casedef.csv but "Malignant tumor of brain" in dx_brain_cancer.csv (workplan 2.1–2.3).
- Structured exposure is orders (MedicationRequest) and procedure or encounter codes, not administration; LLM `ADMINISTERED` mentions are the only receipt evidence. Every administered LLM agent counts as chemotherapy while methotrexate orders do not. Methotrexate serum levels and leucovorin, the strongest structured markers of high-dose methotrexate, have no valueset.
- Vital status reads raw `patient.deceasedBoolean` / `deceasedDateTime`, the last study-population encounter and LLM vital-status mentions; the earliest death and latest alive dates win without cross-checking. A death recorded only by the event task reaches EFS but not OS. Coarse LLM dates (month or year precision) are consumed as exact days.
- The column dictionary covers the cohort, casedef, sample, eligible and outcome tables; client columns live in `client_dictionary.csv`; the LLM wide-table columns and warn tables are in neither.
- Lab valuesets include expanded AST, ALT and platelet LOINCs and local AST/ALT/creatinine codes. Creatinine still contains only one LOINC; proposed multi-site additions remain unimplemented. Hemoglobin still includes local reticulocyte hemoglobin code 923. Estimated and special-context measurements need explicit pooling decisions. No eligible or outcome SQL reads a lab table.
- Boolean wide evidence fields are TRUE or NULL, not proof of clinical absence or treatment receipt. Typed wide tables retain distinct evidence rows rather than one adjudicated result per patient.
- Medication valuesets comprise seven files and 146 entries, including 86 methotrexate codes under `rx_contrast_methotrexate`. Full terminology-release/historical coverage, local mapping, administration ascertainment and clinical validation remain open. The radiation and craniotomy valuesets are candidates marked `[CANDIDATE - verify]`.
- The LLM wide stage runs 8 of 23 builders against four hard-coded deployment suffixes; the client views read 13 tables no stage builds; the compact medulloblastoma task cannot be exported by cumulus-library 6.3.1; no note-selection tables are created for the NLP workflows.
- Package metadata (`pyproject.toml`, "PNOC30") and 46 orphaned generated SQL files retain legacy terminology. They should not be mistaken for implemented PCX survival logic.

## Reference study

ACNS0334 compared high-dose methotrexate added to an intensive chemotherapy backbone,
with induction followed by consolidation and stem-cell support. Its primary endpoint
was complete response after consolidation in baseline-evaluable patients. Molecular
Group 3 analyses were small subgroup comparisons using one-sided tests.

Source: [Mazewski, Leary et al., ACNS0334 report](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/).

## 1. Broad cohort versus trial-like eligibility

**Gap:** The paper uses age under 36 months at definitive surgery and additional eligibility
criteria, including disease risk, prior treatment and organ function. The repository now
has both a discovery cohort (`pcx__eligible`, all ages, every criterion as met / not met /
unknown) and a trial-like cohort (`pcx__eligible_trial`), but the trial view is affected by
the three defects above, the sPNET arm never enters it, organ-function criteria are not
applied, and the definitive operation is identified by free text.

**Consequence:** Selecting young patients with a medulloblastoma diagnosis alone does
not establish comparability with trial participants; the current intersection is both too
permissive (NULL time zero) and too restrictive (requires treatment evidence).

**Resolution:** Keep the two-table design. Fix the NULL handling, treat absence of pre-t0
evidence as "no prior" once t0 is known, decide whether sPNET is in scope, make the
definitive-surgery role an enum, and add staging, residual disease and organ-function
evidence as further nullable criteria. Do not convert undocumented criteria into eligibility.

## 2. Any-dose methotrexate is insufficient treatment specificity

**Gap:** The exposure is any methotrexate order or any LLM-administered methotrexate. That
does not identify the study treatment strategy (high-dose, 5 g/m², with leucovorin rescue
and serum levels) described in the reference paper.

**Resolution:** Retain any-dose exposure for discovery, then capture dose and units,
route, administration dates, induction/consolidation phase, companion agents,
stem-cell rescue, interruptions and discontinuation. Add methotrexate-level and leucovorin
valuesets as structured markers. Separate protocol documentation, intended treatment and
delivered treatment. Do not infer administration from an order or protocol enrollment from
a drug combination.

## 3. Time zero needs an explicit trial-aligned definition

**Gap:** Time zero is the first tier 1 medulloblastoma encounter. The registered EFS
endpoint begins at enrollment and ends at progression/relapse, secondary malignancy or
death, with last-contact censoring for event-free patients. The definitive surgery day,
the LLM tissue-diagnosis date and the first chemotherapy day are kept as separate columns
but none is the origin.

Source: [ACNS0334 registry, NCT00336024](https://clinicaltrials.gov/study/NCT00336024).

**Resolution:** Retain original diagnosis when known, first local diagnosis, definitive
surgery and treatment-initiation dates separately (done). Define an observable EHR equivalent
of enrollment that aligns eligibility assessment, treatment assignment and follow-up, and
reconcile the casedef sampling anchor with it. Report the consequences of alternative
anchors (the `pcx__warn_eligible_t0_*` tables measure them). Do not silently substitute one
date for another or assume the registered EFS origin establishes every OS convention.

## 4. Response assessment is missing; EFS is provisional

**Gap:** OS is implemented; EFS is implemented as provisional (`efs_censor_source =
last_known_alive_provisional`) because event-free follow-up is not adjudicated. Baseline
response evaluability and treatment-phase response assessments are extracted by the
`response` task but its wide table is not built and nothing reads it. Undated events are
invisible to EFS; events before time zero are not excluded.

**Resolution:** Promote EFS to the core reproduction specification and add baseline
measurable/evaluable disease, dated response assessments, consolidation completion,
and early progression/death. Define the response denominator before examining outcomes.
Missing assessments are not complete responses. Require documented event-free follow-up
for EFS censoring; a last-known-alive date alone is insufficient. Retain remission as a
response state rather than automatically counting it as an adverse EFS event.

## 5. Radiation needs temporal context

**Gap:** The paper allowed discretionary radiation after protocol treatment. The
`radiation_prior_to_first_event_bool` flag and the chemotherapy/radiation sequence are
implemented in `pcx__outcome_exposure` by date comparison only. Radiation receipt rests on
procedure or encounter codes and LLM administered rounds; the tier 2 "history of irradiation"
codes are ignored; the LLM `indication` is free text; and the trial-like cohort currently
requires radiation evidence to exist at all.

**Resolution:** Capture delivery dates, field, dose and indication, distinguishing
initial management, post-chemotherapy treatment and salvage after relapse (an indication
enum). A single lifetime radiation flag should not be treated as a baseline treatment
assignment, and its absence should not exclude a subject.

## 6. Molecular labels need provenance and validation

**Gap:** The paper used retrospective methylation-based classification. The `molecular`
task captures method and provenance but has no wide table; the client diagnosis view sources
the molecular group from the compact `medulloblastoma` task, which cannot be exported.

**Resolution:** Build the molecular projections, retain classification method, report date,
source report, supporting spans, uncertainty and conflicting classifications. Validate
extracted Group 3 labels against available pathology/molecular reports. A subtype mentioned
in a note and a molecularly confirmed classification should remain distinguishable.

The paper-specific population, response, radiation and molecular details above are
supported by its [methods and results](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/).

## 7. Observed treatment groups do not recreate randomization

**Gap:** Exposure-timing bias is recognized, but treatment selection and baseline
differences are not yet handled.

**Resolution:** Prespecify the treatment decision point, exposure-assignment window,
comparison groups, baseline covariates and analysis population. Assess confounding,
overlap and missingness before estimating treatment effects. Track later treatment
changes separately. Requiring completion of consolidation for cohort entry would
exclude early failures; including only eventual treatment recipients can also introduce
survival-related selection (the current trial view does exactly this for radiation and
chemotherapy). Report descriptive associations until a defensible observational analysis
is specified.

## 8. Follow-up and cross-network aggregation remain unresolved

**Gap:** Dates, missingness and patient overlap are recognized, but their
operational definitions and network-level analysis method remain unspecified. Death and
alive evidence from different sources are combined by earliest-death / latest-alive without
reconciliation (`pcx__warn_outcome_vital_status_conflict` measures the disagreement).

**Resolution:** Validate death dates, last-known-alive dates and event ascertainment;
retain undated deaths and conflicting records as unresolved. Assess differences in
follow-up, calendar period and documentation by site. Resolve Cumulus/CBTN patient
overlap before pooling. Specify how event, censoring and at-risk counts will be combined.
If count suppression applies, suppressed cells are unknown rather than zero and may
prevent exact survival-curve reconstruction.

## 9. Reproduction needs explicit scope and uncertainty

**Gap:** Nothing yet identifies which paper findings constitute success or what
precision is achievable in the available EHR cohort.

**Resolution:** Prioritize the medulloblastoma/Group 3 comparison explicitly rather than
claiming reproduction of every analysis in the paper. Report cohort flow, exclusions,
missingness, group sizes, event counts, numbers at risk and confidence intervals.
Prespecify subgroup and sensitivity analyses. Assess compatibility of effect direction
and magnitude with uncertainty; matching published percentages or significance alone
is not a sufficient success criterion.

## Delivery milestones

1. **Feasibility:** broad cohort, exposure discovery, subtype availability, dated vital
   status and network-specific completeness. Blocked on workplan phase 1 (the build) and
   phase 2 (the cohort).
2. **Trial-aligned descriptive reproduction:** documented eligibility, sufficiently
   specific treatment groups, response assessment, EFS and OS with uncertainty. Workplan
   phases 3 and 4.
3. **Observational treatment-effect analysis:** explicit baseline treatment strategies,
   confounding assessment, timing controls and sensitivity analyses. Not started.

The repository status was refreshed on 2026-09-11. The original scientific comparison was
recorded on 2026-09-08. These limitations remain open until their definitions, required data
and validation evidence are documented.
