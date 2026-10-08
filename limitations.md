# Limitations and gaps for reproducing ACNS0334 in EHR data

The scientific goal is to assess whether the treatment-associated outcome differences
observed in ACNS0334 are also observed in comparable EHR-derived medulloblastoma
cohorts, prioritizing Group 3.

The study defines a discovery cohort, a trial-like cohort, dated vital status, OS and a
provisional EFS ([eligible.md](eligible.md)). It does not yet specify an observational
treatment-effect analysis. The scientific items below remain gaps with proposed resolutions.
What is decided is in [PROTOCOL.md](PROTOCOL.md); the open work each gap implies is in
[WORKPLAN.md](WORKPLAN.md). No patient data or completed cross-network analysis was audited.

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
unknown) and a trial-like cohort (`pcx__eligible_trial`), but the sPNET arm never enters the
trial view, organ-function criteria are not applied, and the definitive operation is taken
as the earliest recorded resection.

**Consequence:** Selecting young patients with a medulloblastoma diagnosis alone does
not establish comparability with trial participants. A subject with a time zero and no
therapy records counts as "no prior therapy": that is an absence of records, not a
documented absence, so it depends on how complete the site's medication and procedure data are.

**Resolution:** Keep the two-table design. The NULL handling is fixed and absence of pre-t0
evidence is "no prior" once t0 is known (2026-09-30). Still to do: decide whether sPNET is in
scope, and add staging, residual disease and organ-function
evidence as further nullable criteria. Do not convert undocumented criteria into eligibility.

## 2. Any-dose methotrexate is insufficient treatment specificity

**Gap:** The exposure is any methotrexate order, pharmacy dispense or LLM-administered methotrexate. That
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
`response` task and projected to `pcx__llm_response_wide`, which only the client timeline
reads: no eligibility or outcome SQL uses it. Undated events are
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
codes are ignored; and the LLM `indication` is free text.

**Resolution:** Capture delivery dates, field, dose and indication, distinguishing
initial management, post-chemotherapy treatment and salvage after relapse (an indication
enum). A single lifetime radiation flag should not be treated as a baseline treatment
assignment, and its absence does not exclude a subject.

## 6. Molecular labels need provenance and validation

**Gap:** The paper used retrospective methylation-based classification. The `molecular`
task captures method and provenance, projected to the molecular report and alteration
tables. Extracted labels have not been validated against source reports. The WHO CNS5
integrated diagnosis is not extracted, as a classification or as wording, so a documented
integrated diagnosis cannot be checked against the extracted molecular group. Tumor location,
laterality and germline predisposition are not extracted either, which rules out anatomical
comparisons and SHH-specific covariates for now (WORKPLAN.md, Clinical notes).

**Resolution:** Retain classification method, report date,
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
survival-related selection. Report descriptive associations until a defensible observational analysis
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
   status and network-specific completeness. The build runs; the cohort items are open in
   WORKPLAN.md (Case definition, Eligibility).
2. **Trial-aligned descriptive reproduction:** documented eligibility, sufficiently
   specific treatment groups, response assessment, EFS and OS with uncertainty. Open in
   WORKPLAN.md (Eligibility, Outcomes, Clinical notes).
3. **Observational treatment-effect analysis:** explicit baseline treatment strategies,
   confounding assessment, timing controls and sensitivity analyses. Not started.

The original scientific comparison was recorded on 2026-09-08. This file was checked against
the code on 2026-10-08, when the dated list of implementation findings was removed (it is in
git history). These limitations remain open until their definitions, required data and
validation evidence are documented.
