"""PCX topic-relevance routing for one clinical document."""

from enum import StrEnum

from pydantic import BaseModel, Field

from cumulus_library_pcx.llm.models.base import SpanAugmentedMention


class TopicRelevance(StrEnum):
    """Highest level of patient-specific evidence for a requested topic."""

    EXPLICIT = "EXPLICIT"
    IMPLICIT = "IMPLICIT"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class TopicRelevanceMention(SpanAugmentedMention):
    """Classify one fixed PCX topic using patient-specific document evidence."""

    relevance: TopicRelevance = Field(
        default=TopicRelevance.NONE_OF_THE_ABOVE,
        description=(
            "EXPLICIT when the topic is directly named or measured for this patient. "
            "IMPLICIT only when the document contains the topic-specific supporting "
            "facts in the parent field description. NONE_OF_THE_ABOVE when neither "
            "level is supported. Explicit negative tests and non-receipt statements are "
            "relevant to staging, treatment, molecular testing and eligibility. "
            "Exclude hypothetical/rule-out disease and family history unless requested."
        ),
    )
    confidence: float | None = Field(
        default=None,
        ge=0.0,
        le=1.0,
        description="Confidence in the relevance classification from 0.0 to 1.0.",
    )
    reasoning: str | None = Field(
        default=None,
        description=(
            "One concise sentence applying the parent field definition to the cited "
            "spans. Null for NONE_OF_THE_ABOVE."
        ),
    )


class TopicRelevanceAnnotation(BaseModel):
    """Wide-friendly routing gate for the PCX extraction models.

    Each routing field matches its extraction module's filename without ``.py``.
    """

    response: TopicRelevanceMention = Field(
        ...,
        description=(
            "Baseline measurable/evaluable disease, CR/PR/SD/PD, end-induction or end-consolidation assessment, "
            "including explicitly negative MRI/CSF findings.")
    )
    diagnosis: TopicRelevanceMention = Field(
        ...,
        description=(
            "ATRT, medulloblastoma, other CNS embryonal diagnosis, WHO-CNS5 "
            "integrated diagnosis, primary site, laterality, or diagnosis date."
        ),
    )
    molecular: TopicRelevanceMention = Field(
        ...,
        description=(
            "Medulloblastoma subgroup, MYC/MYCN, chromosome alterations, assay provenance, "
            "WNT/SHH/Group 3/Group 4, methylation class, or a qualifying pathology "
            "and molecular report."
        ),
    )
    event: TopicRelevanceMention = Field(
        ...,
        description=(
            "Initial diagnosis, progression, recurrence, refractory disease, second "
            "malignancy, second primary, death, response, or current disease status."
        ),
    )
    metastasis: TopicRelevanceMention = Field(
        ...,
        description=(
            "Chang M stage, brain/spine metastatic imaging, CSF cytology, "
            "leptomeningeal spread, or extraneural metastatic disease."
        ),
    )
    surgery: TopicRelevanceMention = Field(
        ...,
        description=(
            "Tumor biopsy/resection, surgery date, procedure type, or extent of "
            "resection."
        ),
    )
    radiation: TopicRelevanceMention = Field(
        ...,
        description=(
            "Radiation course, modality, field, start/stop date, craniospinal or "
            "focal treatment, and dose."
        ),
    )
    systemic_therapy: TopicRelevanceMention = Field(
        ...,
        description=(
            "Chemotherapy protocol, regimen, cycle, administered agent, dose, route, "
            "high-dose methotrexate, induction/consolidation, stem-cell rescue or prior treatment."
        ),
    )
    laboratory: TopicRelevanceMention = Field(
        ...,
        description=(
            "Hemoglobin, platelets, absolute neutrophils, creatinine, ALT, AST, "
            "bilirubin, creatinine clearance/measured GFR, MTX level, or documented toxicity. "
            "Include explicit normal and abnormal results; absent testing is not a negative result."
        ),
    )
    predisposition: TopicRelevanceMention = Field(
        ...,
        description=(
            "Patient germline findings such as SUFU, PTCH1, TP53 or other documented predisposition; include negative tests and VUS."
        ),
    )
    patient: TopicRelevanceMention = Field(
        ...,
        description=(
            "Initial tumor-detecting MRI date, vital status, last known alive date, "
            "death date, event-free follow-up, definitive surgery, treatment initiation or actual trial enrollment."
        ),
    )
    registry_eligibility: TopicRelevanceMention = Field(
        ...,
        description=(
            "ACNS0334 comparability: age at definitive surgery, newly diagnosed high-risk "
            "embryonal disease, ATRT exclusion/reclassification, pretreatment history "
            "or renal/hepatic/cardiac/pulmonary/marrow adequacy. Include explicit negatives."
        ),
    )


DocumentTopicAnnotation = TopicRelevanceAnnotation
