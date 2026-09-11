## Deferred tasks

- [ ] Restore structured tumor laterality extraction if a future analysis needs
  surgical approach, neurologic outcomes, or anatomical comparisons. Deferred
  2026-09-10 because a separate laterality classification is not needed for the
  current cohort eligibility workflow. Keep
  `tumor_location_verbatim` in the diagnosis model in the meantime.
  - Previous enum: `Laterality` with `LEFT`, `RIGHT`, `BILATERAL`, `MIDLINE`,
    and `NONE_OF_THE_ABOVE`.
  - Restore a flat `DiagnosisAnnotation.laterality` enum field only when
    required; do not reintroduce the old mention wrapper. Update the
    diagnosis/routing JSON schemas, wide-table template and builder, task
    version, and regression checks together.

- [ ] Integrated diagnosis classification (deferred 2026-09-10). Defer detailed molecular classification from diagnosis extraction; use the molecular task for subgroup analyses. Retain `historical_diagnosis_term`; integrated-diagnosis wording is also deferred below.
  - Previous enum: `CnsIntegratedDiagnosis`; values: `ATRT_SHH`, `ATRT_MYC`, `ATRT_TYR`, `ATRT_NOS`, `MB_WNT`, `MB_SHH_TP53_WILDTYPE`, `MB_SHH_TP53_MUTANT`, `MB_NON_WNT_NON_SHH`, `MB_GROUP_3`, `MB_GROUP_4`, `MB_NOS`, `ETMR`, `PINEOBLASTOMA`, `LEGACY_SPNET`, `OTHER_CNS_EMBRYONAL`, `OTHER`, `NONE_OF_THE_ABOVE`.
  - Restore the `integrated_diagnosis` classification as a flat diagnosis field only when needed; update the diagnosis schema, wide-table SQL/builder, task version, and regression checks together.

- [ ] Tumor location classification (deferred 2026-09-10). Defer detailed anatomic categories while retaining `tumor_location_verbatim` for historical diagnosis review.
  - Previous enum: `TumorLocation`; values: `CEREBELLUM_POSTERIOR_FOSSA`, `FOURTH_VENTRICLE`, `CEREBRAL_HEMISPHERE`, `DEEP_SUPRATENTORIAL`, `SUPRASELLAR_PITUITARY`, `PINEAL`, `BRAINSTEM`, `VENTRICLES_OTHER`, `SPINAL_CORD`, `OPTIC_PATHWAY`, `MENINGES_DURA`, `OTHER`, `NONE_OF_THE_ABOVE`.
  - Restore the `tumor_location` classification as a flat diagnosis field only when needed; update the diagnosis schema, wide-table SQL/builder, task version, and regression checks together.

- [ ] **Low priority — IntegratedDiagnosisMention: later validation.** Defer extraction
  of `integrated_diagnosis_verbatim` until validating documented integrated
  diagnoses against the molecular task's classifications. It is not needed for
  the current eligibility pass. Historical terminology remains active in
  `DiseaseSubtypeMention.historical_diagnosis_term`.
  - Previously returned an exact WHO-CNS5 diagnosis phrase (for example,
    "Medulloblastoma, SHH-activated and TP53-mutant"), or null when unstated,
    together with evidence spans and a mention flag.
  - Before restoring, establish the validation question and avoid duplicating
    molecular classification. Update schema, SQL, builder, version, and tests.

The current diagnosis model uses mention wrappers with evidence spans. Integrated
wording is deferred; historical diagnosis and primary-site wording remain active.
