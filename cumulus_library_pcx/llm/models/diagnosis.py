"""Flat PCX diagnosis evidence from one note; eligibility is adjudicated downstream."""
from datetime import date
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, model_validator
from cumulus_library_pcx.llm.models.base import DatePrecision


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


class PcxDiagnosisAnnotation(BaseModel):
    """Extract confirmed patient-specific diagnoses, including documented history.
    Exclude suspected, negated, rule-out, and family-history diagnoses. Preserve
    exact diagnosis/site wording and legacy terms without inferring modern entities.
    Molecular classification is handled separately. Unknown findings do not imply
    eligibility or exclusion. Extract only explicitly documented M-stage; do not
    derive it from imaging or cytology here. Histology is unknown when unstated or
    not medulloblastoma. Prefer imaging impression for primary tumor-site wording.
    """
    model_config = ConfigDict(extra="forbid")

    disease_subtype: DiseaseSubtype = Field(
        default=DiseaseSubtype.NONE_OF_THE_ABOVE,
        description=(
            "Documented diagnosis using only evidence from this note. Choose exactly one. "
            "ATRT: atypical teratoid/rhabdoid tumor, AT/RT, malignant rhabdoid tumor of the "
            "CNS. Record ATRT as an exclusion/reclassification; do not infer it from a marker alone. "
            "MEDULLOBLASTOMA: medulloblastoma of any histology or molecular group (WNT, SHH, "
            "Group 3, Group 4), incl. medullomyoblastoma and MBEN. "
            "ETMR: embryonal tumor with multilayered rosettes. PINEOBLASTOMA: pineoblastoma. "
            "LEGACY_SPNET: historical supratentorial PNET/CNS-PNET without a modern diagnosis. "
            "OTHER_CNS_EMBRYONAL: other embryonal CNS tumor or embryonal tumor NOS. "
            "NONE_OF_THE_ABOVE: no embryonal-tumor diagnosis is documented in this note."
        ),
    )

    medulloblastoma_histology: MedulloblastomaHistology = Field(
        default=MedulloblastomaHistology.NONE_OF_THE_ABOVE,
        description=(
            "CLASSIC: classic medulloblastoma. "
            "DESMOPLASTIC_NODULAR: desmoplastic/nodular. "
            "EXTENSIVE_NODULARITY_MBEN: medulloblastoma with extensive nodularity (MBEN). "
            "LARGE_CELL_ANAPLASTIC: large-cell and/or anaplastic. "
            "NONE_OF_THE_ABOVE: histologic pattern not stated or not a medulloblastoma."
        ),
    )

    integrated_diagnosis_verbatim: str | None = Field(
        default=None,
        description=(
            "The exact WHO-CNS5 integrated-diagnosis phrase as written in the note (e.g. "
            "'Medulloblastoma, SHH-activated and TP53-mutant'). Null if not stated."
        ),
    )

    historical_diagnosis_term: str | None = Field(
        default=None,
        description=(
            "A deprecated or legacy (pre-WHO-CNS5) diagnosis term the note uses for THIS tumor "
            "-- e.g. 'PNET', 'CNS-PNET', 'supratentorial PNET', 'cerebellar sarcoma', "
            "'medulloblastoma variant'. Capture the exact historical phrase verbatim so a "
            "downstream crosswalk can review it against a current diagnosis; do not infer a modern entity from a legacy term. Null "
            "when the note uses only current integrated-diagnosis terminology, or no such term "
            "is stated. Do not record family-history, negated, or rule-out terms."
        ),
    )

    tumor_location_verbatim: str | None = Field(
        default=None,
        description="Exact site phrase from the note (e.g. 'left cerebellar hemisphere'). Null if not stated.",
    )

    chang_m_stage: ChangMStage = Field(
        default=ChangMStage.NONE_OF_THE_ABOVE,
        description=(
            "M0: no metastasis (localized). M1: positive CSF cytology only. "
            "M2: intracranial metastasis beyond primary. M3: spinal/leptomeningeal metastasis. "
            "M4: metastasis outside the CNS. NONE_OF_THE_ABOVE: M-stage not documented."
        ),
    )

    age_at_diagnosis_months: int | None = Field(
        default=None, ge=0, le=1500,
        description="Explicit age at initial diagnosis in completed months (e.g. '2 years' -> 24); not age at definitive surgery. Null if unstated.",
    )

    diagnosis_date: str | None = Field(
        default=None,
        description="Earliest diagnosis date, ISO YYYY-MM-DD (first-of-period if coarse). Null if not stated.",
    )

    diagnosis_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision supported by the text for diagnosis_date. Null when diagnosis_date is null.",
    )

    diagnosis_date_gold: str | None = Field(
        default=None,
        description="Confirmatory tissue-diagnosis date: prefer the biopsy/resection date producing the diagnostic specimen over the report date. ISO YYYY-MM-DD, first-of-period if coarse; null if unstated. Not necessarily definitive surgery.",
    )

    diagnosis_date_gold_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for diagnosis_date_gold. Null when diagnosis_date_gold is null.",
    )

    @model_validator(mode="after")
    def validate_date_precision(self):
        for name in ("diagnosis_date", "diagnosis_date_gold"):
            value = getattr(self, name)
            precision = getattr(self, f"{name}_precision")
            if (value is None) != (precision is None):
                raise ValueError(f"{name} and its precision must both be present or null")
            if value is None:
                continue
            parsed = date.fromisoformat(value)
            if parsed.isoformat() != value:
                raise ValueError(f"{name} must use YYYY-MM-DD")
            if precision == DatePrecision.MONTH and parsed.day != 1:
                raise ValueError("Month-precision dates must use the first day of the month")
            if precision == DatePrecision.YEAR and (parsed.month, parsed.day) != (1, 1):
                raise ValueError("Year-precision dates must use January 1")
        return self
