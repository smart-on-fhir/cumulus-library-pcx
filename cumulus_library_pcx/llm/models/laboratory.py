"""Optional PCX laboratory and toxicity evidence for trial comparability.

PMC12833527 describes organ-function eligibility and CTCAE toxicity. Specific routine
eligibility tests are listed in NCT00336024 and its participating-site descriptions.
These are supporting measurements, not the paper's primary efficacy endpoints.
Prefer structured lab results; extract narrative results only when documented.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .base import SpanAugmentedMention, DatePrecision
from .lab_base import LabBaseMention
from .treatment import TreatmentPhase


class LaboratoryTest(StrEnum):
    """Study-specific laboratory test. Closed list: a result for any test not listed
    here is not extracted at all (no mention is produced for it).
    ABSOLUTE_NEUTROPHIL_COUNT: absolute neutrophil count (ANC).
    PLATELET_COUNT: platelet count.
    HEMOGLOBIN: hemoglobin.
    CREATININE_CLEARANCE: creatinine clearance.
    MEASURED_GFR: measured glomerular filtration rate.
    SERUM_CREATININE: serum creatinine.
    TOTAL_BILIRUBIN: total bilirubin.
    AST: aspartate aminotransferase.
    ALT: alanine aminotransferase.
    METHOTREXATE_LEVEL: methotrexate level."""
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


class LaboratoryResultMention(LabBaseMention):
    """One documented laboratory result. Value, unit, trend and the three interpretation
    fields come from LabBaseMention. A qualitative result keeps value_numeric null."""
    test: LaboratoryTest = Field(description="Which study-specific test this result is. Only tests in LaboratoryTest are extracted; omit results for any other test.")
    reference_range: str | None = Field(default=None, description="Documented normal range or upper limit of normal, including age context.")
    collection_date: str | None = Field(default=None, description="Specimen/measurement date, ISO date at supported precision.")
    collection_date_precision: DatePrecision | None = Field(default=None, description="Precision for collection_date; null if absent.")

class ToxicityMention(SpanAugmentedMention):
    toxicity: str = Field(description="Documented adverse event; do not infer toxicity from a lab without clinical interpretation.")
    grade: int | None = Field(default=None, ge=1, le=5, description="Explicit CTCAE grade; never infer from a value alone.")
    grading_system: str | None = Field(default=None, description="Named grading system/version if stated; do not assume CTCAE v4 because the paper used it.")
    phase: TreatmentPhase = Field(default=TreatmentPhase.NOT_DOCUMENTED)
    event_date: str | None = Field(default=None, description="Documented toxicity date, ISO date at supported precision.")
    event_date_precision: DatePrecision | None = Field(default=None, description="Precision for event_date; null if absent.")
    attribution: str | None = Field(default=None, description="Clinician-attributed relationship to treatment, including treatment-related death only if explicitly stated.")


class LaboratoryAnnotation(BaseModel):
    results: list[LaboratoryResultMention] = Field(default_factory=list, description="Results for the study-specific tests in LaboratoryTest only. Do not include a result for any other laboratory test; leave the list empty if none of the listed tests are documented.")
    toxicities: list[ToxicityMention] = Field(default_factory=list)
