# Limitations and gaps for reproducing ACNS0334 in EHR data

The scientific goal is to assess whether the treatment-associated outcome differences
observed in ACNS0334 are also observed in comparable EHR-derived medulloblastoma
cohorts, prioritizing Group 3.

The current [README](README.md) defines a useful feasibility cohort and OS comparison.
It does not yet specify a trial-aligned reproduction or an observational treatment-effect
analysis. The items below are gaps in that specification and proposed resolutions;
they are not findings from an audit of patient data or a completed implementation.

## Reference study

ACNS0334 compared high-dose methotrexate added to an intensive chemotherapy backbone,
with induction followed by consolidation and stem-cell support. Its primary endpoint
was complete response after consolidation in baseline-evaluable patients. Molecular
Group 3 analyses were small subgroup comparisons using one-sided tests.

Source: [Mazewski, Leary et al., ACNS0334 report](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/).

## 1. Broad cohort versus trial-like eligibility

**Gap:** The README includes all ages and distinguishes age at diagnosis. The paper
uses age under 36 months at definitive surgery and additional eligibility criteria,
including disease risk, prior treatment and organ function.

**Consequence:** Selecting young patients with a medulloblastoma diagnosis alone does
not establish comparability with trial participants.

**Resolution:** Preserve the broad discovery cohort and define a separate trial-like
cohort. Capture definitive surgery date, staging, residual disease, histology,
pretreatment history and relevant organ-function evidence. Represent eligibility as
met, not met or unknown; do not convert undocumented criteria into eligibility.

## 2. Any-dose methotrexate is insufficient treatment specificity

**Gap:** The README distinguishes receipt of any dose. That does not identify the
study treatment strategy described in the reference paper.

**Resolution:** Retain any-dose exposure for discovery, then capture dose and units,
route, administration dates, induction/consolidation phase, companion agents,
stem-cell rescue, interruptions and discontinuation. Separate protocol documentation,
intended treatment and delivered treatment. Do not infer administration from an order
or protocol enrollment from a drug combination.

## 3. Time zero needs an explicit trial-aligned definition

**Gap:** The README uses first recorded diagnosis. The registered EFS endpoint begins
at enrollment and ends at progression/relapse, secondary malignancy or death, with
last-contact censoring for event-free patients.

Source: [ACNS0334 registry, NCT00336024](https://clinicaltrials.gov/study/NCT00336024).

**Resolution:** Retain original diagnosis when known, first local diagnosis, definitive
surgery and treatment-initiation dates separately. Define an observable EHR equivalent
of enrollment that aligns eligibility assessment, treatment assignment and follow-up.
Report the consequences of alternative anchors. Do not silently substitute one date
for another or assume the registered EFS origin establishes every OS convention.

## 4. Response assessment is missing; EFS is still optional

**Gap:** The README prioritizes OS and leaves EFS as a reach goal. It does not define
baseline response evaluability or treatment-phase response assessments.

**Resolution:** Promote EFS to the core reproduction specification and add baseline
measurable/evaluable disease, dated response assessments, consolidation completion,
and early progression/death. Define the response denominator before examining outcomes.
Missing assessments are not complete responses. Require documented event-free follow-up
for EFS censoring; a last-known-alive date alone is insufficient. Retain remission as a
response state rather than automatically counting it as an adverse EFS event.

## 5. Radiation needs temporal context

**Gap:** The paper allowed discretionary radiation after protocol treatment; the README
uses any-radiation receipt.

**Resolution:** Capture delivery dates, field, dose and indication, distinguishing
initial management, post-chemotherapy treatment and salvage after relapse. A single
lifetime radiation flag should not be treated as a baseline treatment assignment.

## 6. Molecular labels need provenance and validation

**Gap:** The paper used retrospective methylation-based classification. The README
allows subtype extraction from clinical documentation.

**Resolution:** Retain classification method, report date, source report, supporting
spans, uncertainty and conflicting classifications. Validate extracted Group 3 labels
against available pathology/molecular reports. A subtype mentioned in a note and a
molecularly confirmed classification should remain distinguishable.

The paper-specific population, response, radiation and molecular details above are
supported by its [methods and results](https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/).

## 7. Observed treatment groups do not recreate randomization

**Gap:** The README recognizes exposure-timing bias but does not specify how treatment
selection and baseline differences will be handled.

**Resolution:** Prespecify the treatment decision point, exposure-assignment window,
comparison groups, baseline covariates and analysis population. Assess confounding,
overlap and missingness before estimating treatment effects. Track later treatment
changes separately. Requiring completion of consolidation for cohort entry would
exclude early failures; including only eventual treatment recipients can also introduce
survival-related selection. Report descriptive associations until a defensible
observational analysis is specified.

## 8. Follow-up and cross-network aggregation remain unresolved

**Gap:** Dates, missingness and patient overlap are recognized in the README, but their
operational definitions and network-level analysis method remain unspecified.

**Resolution:** Validate death dates, last-known-alive dates and event ascertainment;
retain undated deaths and conflicting records as unresolved. Assess differences in
follow-up, calendar period and documentation by site. Resolve Cumulus/CBTN patient
overlap before pooling. Specify how event, censoring and at-risk counts will be combined.
If count suppression applies, suppressed cells are unknown rather than zero and may
prevent exact survival-curve reconstruction.

## 9. Reproduction needs explicit scope and uncertainty

**Gap:** The README does not identify which paper findings constitute success or what
precision is achievable in the available EHR cohort.

**Resolution:** Prioritize the medulloblastoma/Group 3 comparison explicitly rather than
claiming reproduction of every analysis in the paper. Report cohort flow, exclusions,
missingness, group sizes, event counts, numbers at risk and confidence intervals.
Prespecify subgroup and sensitivity analyses. Assess compatibility of effect direction
and magnitude with uncertainty; matching published percentages or significance alone
is not a sufficient success criterion.

## Delivery milestones

1. **Feasibility:** broad cohort, exposure discovery, subtype availability, dated vital
   status and network-specific completeness.
2. **Trial-aligned descriptive reproduction:** documented eligibility, sufficiently
   specific treatment groups, response assessment, EFS and OS with uncertainty.
3. **Observational treatment-effect analysis:** explicit baseline treatment strategies,
   confounding assessment, timing controls and sensitivity analyses.

Recorded on 2026-09-08 from the paper-to-README comparison. These limitations remain
open until their definitions, required data and validation evidence are documented.
