"""Optional PCX laboratory and toxicity evidence for trial comparability.

PMC12833527 describes organ-function eligibility and CTCAE toxicity. Specific routine
eligibility tests are listed in NCT00336024 and its participating-site descriptions.
These are supporting measurements, not the paper's primary efficacy endpoints.
Prefer structured lab results; extract narrative results only when documented.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .base import SpanAugmentedMention, DatePrecision
from .treatment import TreatmentPhase


class LaboratoryTest(StrEnum):
    ABSOLUTE_NEUTROPHIL_COUNT = "ABSOLUTE_NEUTROPHIL_COUNT"
    PLATELET_COUNT = "PLATELET_COUNT"
    HEMOGLOBIN = "HEMOGLOBIN"
    CREATININE_CLEARANCE = "CREATININE_CLEARANCE"
    MEASURED_GFR = "MEASURED_GFR"
    SERUM_CREATININE = "SERUM_CREATININE"
    TOTAL_BILIRUBIN = "TOTAL_BILIRUBIN"
    AST = "AST"
    ALT = "ALT"
    METHOTREXATE_LEVEL = "METHOTREXATE_LEVEL"
    OTHER = "OTHER"


class LaboratoryResultMention(SpanAugmentedMention):
    test: LaboratoryTest
    result_verbatim: str = Field(description="Exact value, comparator and units. Preserve age-specific normal ranges and whether GFR is indexed. Serum creatinine is not interchangeable with measured GFR/clearance.")
    value: float | None = Field(default=None, description="Numeric reported result; null for qualitative results. Retain inequalities in result_verbatim.")
    units: str | None = Field(default=None, description="Exact documented units; do not invent or convert units.")
    reference_range: str | None = Field(default=None, description="Documented normal range or upper limit of normal, including age context.")
    collection_date: str | None = Field(default=None, description="Specimen/measurement date, ISO date at supported precision.")
    collection_date_precision: DatePrecision | None = Field(default=None, description="Precision for collection_date; null if absent.")
    context: str | None = Field(default=None, description="Baseline eligibility, on-treatment toxicity or MTX clearance; include hours after MTX and transfusion context only if stated.")


class ToxicityMention(SpanAugmentedMention):
    toxicity: str = Field(description="Documented adverse event; do not infer toxicity from a lab without clinical interpretation.")
    grade: int | None = Field(default=None, ge=1, le=5, description="Explicit CTCAE grade; never infer from a value alone.")
    grading_system: str | None = Field(default=None, description="Named grading system/version if stated; do not assume CTCAE v4 because the paper used it.")
    phase: TreatmentPhase = Field(default=TreatmentPhase.NOT_DOCUMENTED)
    event_date: str | None = Field(default=None, description="Documented toxicity date, ISO date at supported precision.")
    event_date_precision: DatePrecision | None = Field(default=None, description="Precision for event_date; null if absent.")
    attribution: str | None = Field(default=None, description="Clinician-attributed relationship to treatment, including treatment-related death only if explicitly stated.")


class PcxLaboratoryAnnotation(BaseModel):
    results: list[LaboratoryResultMention] = Field(default_factory=list)
    toxicities: list[ToxicityMention] = Field(default_factory=list)
