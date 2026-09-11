"""PCX diagnosis evidence from one note, with verbatim spans; eligibility is adjudicated downstream."""
from enum import StrEnum

from pydantic import BaseModel, Field
from cumulus_library_pcx.llm.models.base import SpanAugmentedMention, DatePrecision


class DiseaseSubtype(StrEnum):
    """Embryonal diagnoses, including exclusions and historical classifications."""
    ATRT = "ATRT"
    MEDULLOBLASTOMA = "MEDULLOBLASTOMA"
    ETMR = "ETMR"
    PINEOBLASTOMA = "PINEOBLASTOMA"
    LEGACY_SPNET = "LEGACY_SPNET"
    OTHER_CNS_EMBRYONAL = "OTHER_CNS_EMBRYONAL"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class MedulloblastomaHistology(StrEnum):
    """WHO histologic pattern of medulloblastoma (distinct from molecular group)."""
    CLASSIC = "CLASSIC"
    DESMOPLASTIC_NODULAR = "DESMOPLASTIC_NODULAR"
    EXTENSIVE_NODULARITY_MBEN = "EXTENSIVE_NODULARITY_MBEN"
    LARGE_CELL_ANAPLASTIC = "LARGE_CELL_ANAPLASTIC"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class ChangMStage(StrEnum):
    """Chang metastasis stage (Chang M-stage). Direct-extraction fallback; the derived
    stage is to be adjudicated downstream from the metastasis.py staging inputs."""
    M0 = "M0"
    M1 = "M1"
    M2 = "M2"
    M3 = "M3"
    M4 = "M4"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class DiseaseSubtypeMention(SpanAugmentedMention):
    """The patient's documented CNS embryonal tumor diagnosis. Choose the single best
    subtype supported by pathology/molecular text in THIS note. Do not extract negated,
    rule-out, suspected/probable, or family-history diagnoses."""
    disease_subtype: DiseaseSubtype = Field(
        default=DiseaseSubtype.NONE_OF_THE_ABOVE,
        description=(
            "Documented diagnosis using only evidence from this note. "
            "Choose exactly one. "
            "ATRT: atypical teratoid/rhabdoid tumor, AT/RT, malignant rhabdoid tumor of the CNS. "
            "Record ATRT as an exclusion/reclassification; do not infer it from a marker alone. "
            "MEDULLOBLASTOMA: medulloblastoma of any histology or molecular group (WNT, SHH, Group 3, Group 4), "
            "include medullomyoblastoma and MBEN. "
            "ETMR: embryonal tumor with multilayered rosettes. "
            "PINEOBLASTOMA: pineoblastoma. "
            "LEGACY_SPNET: historical supratentorial PNET/CNS-PNET without a modern diagnosis. "
            "OTHER_CNS_EMBRYONAL: other embryonal CNS tumor or embryonal tumor NOS. "
            "NONE_OF_THE_ABOVE: no embryonal-tumor diagnosis is documented in this note."
        ),
    )

    historical_diagnosis_term: str | None = Field(
        default=None,
        description=(
            "A deprecated or legacy (pre-WHO-CNS5) diagnosis term the note uses for THIS tumor "
            "-- e.g. 'PNET', 'CNS-PNET', 'supratentorial PNET', 'cerebellar sarcoma', "
            "'medulloblastoma variant'. Capture the exact historical phrase verbatim so a "
            "downstream crosswalk can review it against a current diagnosis; do not infer a "
            "modern entity from a legacy term. Null when the note uses only current "
            "integrated-diagnosis terminology, or no such term is stated. Do not record "
            "family-history, negated, or rule-out terms."
        ),
    )


class MedulloblastomaHistologyMention(SpanAugmentedMention):
    """Histologic pattern when the diagnosis is medulloblastoma. Leave NONE_OF_THE_ABOVE if
    the histologic pattern is not stated or the tumor is not a medulloblastoma."""
    histology: MedulloblastomaHistology = Field(
        default=MedulloblastomaHistology.NONE_OF_THE_ABOVE,
        description=(
            "Choose exactly one. "
            "CLASSIC: classic medulloblastoma. "
            "DESMOPLASTIC_NODULAR: desmoplastic/nodular. "
            "EXTENSIVE_NODULARITY_MBEN: medulloblastoma with extensive nodularity (MBEN). "
            "LARGE_CELL_ANAPLASTIC: large-cell and/or anaplastic. "
            "NONE_OF_THE_ABOVE: histologic pattern not stated or not a medulloblastoma."
        ),
    )


class TumorLocationMention(SpanAugmentedMention):
    """Primary anatomic site of the tumor as the note words it. Prefer the imaging
    impression, then the pathology gross description."""
    tumor_location_verbatim: str | None = Field(
        default=None,
        description="Exact site phrase from the note (e.g. 'left cerebellar hemisphere'). Null if not stated.",
    )


class ChangMStageMention(SpanAugmentedMention):
    """Documented Chang metastasis stage (M-stage) at diagnosis/staging, when stated
    directly. Do not derive it from imaging or cytology here; the derived stage is
    adjudicated downstream from the metastasis.py inputs."""
    chang_m_stage: ChangMStage = Field(
        default=ChangMStage.NONE_OF_THE_ABOVE,
        description=(
            "M0: no metastasis (localized). M1: positive CSF cytology only. "
            "M2: intracranial metastasis beyond primary. M3: spinal/leptomeningeal metastasis. "
            "M4: metastasis outside the CNS. NONE_OF_THE_ABOVE: M-stage not documented."
        ),
    )


class AgeAtDiagnosisMention(SpanAugmentedMention):
    """Patient's age at initial diagnosis in completed months. Extract only if explicitly
    stated. Preserve all ages; age at definitive surgery is a separate trial criterion."""
    age_at_diagnosis_months: int | None = Field(
        default=None, ge=0, le=1500,
        description=("Explicit age at initial diagnosis in completed months (e.g. '2 years' -> 24); "
                    "not age at definitive surgery. "
                     "Null if unstated."),
    )


class DiagnosisDateMention(SpanAugmentedMention):
    """Date the patient was first diagnosed with this embryonal tumor. If several dates
    appear, use the earliest diagnosis date."""
    diagnosis_date: str | None = Field(
        default=None,
        description=("Earliest diagnosis date, ISO YYYY-MM-DD (first-of-period if coarse). "
                     "Null if not stated."),
    )
    diagnosis_date_precision: DatePrecision | None = Field(
        default=None,
        description=("Precision supported by the text for diagnosis_date. "
                     "Null when diagnosis_date is null."),
    )


class DiagnosisDateGoldMention(SpanAugmentedMention):
    """Date of the confirmatory ('gold standard') tissue diagnosis: prefer the surgery /
    biopsy procedure date that produced the diagnostic specimen over a later report date.
    Not necessarily the definitive surgery."""
    diagnosis_date_gold: str | None = Field(
        default=None,
        description=("Confirmatory tissue-diagnosis date, ISO YYYY-MM-DD, first-of-period if coarse. "
                     "Null if unstated."),
    )
    diagnosis_date_gold_precision: DatePrecision | None = Field(
        default=None,
        description=("Precision for diagnosis_date_gold. "
                     "Null when diagnosis_date_gold is null."),
    )


class DiagnosisAnnotation(BaseModel):
    """Extract confirmed patient-specific diagnoses, including documented history.
    Exclude suspected, negated, rule-out, and family-history diagnoses. Preserve
    exact diagnosis/site wording and legacy terms without inferring modern entities.
    Molecular classification is handled separately. Unknown findings do not imply
    eligibility or exclusion. Extract only explicitly documented M-stage; do not
    derive it from imaging or cytology here. Histology is unknown when unstated or
    not medulloblastoma. Every mention carries verbatim spans; has_mention must agree
    with the spans.
    """
    disease_subtype: DiseaseSubtypeMention
    medulloblastoma_histology: MedulloblastomaHistologyMention
    tumor_location: TumorLocationMention
    chang_m_stage: ChangMStageMention
    age_at_diagnosis: AgeAtDiagnosisMention
    diagnosis_date: DiagnosisDateMention
    diagnosis_date_gold: DiagnosisDateGoldMention
