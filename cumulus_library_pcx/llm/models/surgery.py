"""PCX tumor surgery and postoperative residual disease for ACNS0334 comparison.
Capture definitive surgery separately from second-look and recurrence surgery.
Do not infer residual area from resection labels or impose a threshold during extraction."""
from enum import StrEnum
from pydantic import BaseModel, Field

from cumulus_library_pcx.llm.models.base import SpanAugmentedMention, DatePrecision


class SurgeryType(StrEnum):
    """Completed tumor-directed surgical procedure."""
    CRANIOTOMY = "CRANIOTOMY"
    SPINAL_LAMINECTOMY = "SPINAL_LAMINECTOMY"
    ENDOSCOPIC_ENDONASAL = "ENDOSCOPIC_ENDONASAL"
    STEREOTACTIC_BIOPSY = "STEREOTACTIC_BIOPSY"
    LITT = "LITT"
    OTHER = "OTHER"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class ExtentOfResection(StrEnum):
    """Documented extent of tumor resection."""
    GROSS_TOTAL_RESECTION = "GROSS_TOTAL_RESECTION"
    NEAR_TOTAL_RESECTION = "NEAR_TOTAL_RESECTION"
    PARTIAL_RESECTION = "PARTIAL_RESECTION"
    BIOPSY = "BIOPSY"
    NOT_AVAILABLE = "NOT_AVAILABLE"


class SurgeryMention(SpanAugmentedMention):
    """A single neurosurgical procedure for the tumor, with its type, resection extent, and
    date. Emit one SurgeryMention per distinct operation documented in this note."""
    surgery_role: str | None = Field(default=None, description="Documented role: definitive initial surgery, second-look after induction, or recurrence/salvage. Null if unstated.")
    age_at_surgery_months: float | None = Field(default=None, ge=0, description="Explicit age at this operation in months. Do not substitute age at diagnosis or restrict to under 36 months.")
    residual_tumor_area_cm2: float | None = Field(default=None, ge=0, description="Explicit postoperative residual tumor AREA in cm2. Do not convert a length or volume to area, or infer from GTR/NTR/STR.")
    residual_measurement_verbatim: str | None = Field(default=None, description="Exact residual dimensions and units, including inequalities. Preserve even when area cannot be extracted.")
    residual_assessment_date: str | None = Field(default=None, description="Postoperative imaging assessment date, ISO date at supported precision; not automatically surgery date.")
    residual_assessment_date_precision: DatePrecision | None = Field(default=None, description="Precision of residual_assessment_date; null when absent.")
    surgery_type: SurgeryType = Field(
        default=SurgeryType.NONE_OF_THE_ABOVE,
        description=(
            "CRANIOTOMY: open cranial tumor resection/debulking. "
            "SPINAL_LAMINECTOMY: spinal laminectomy for tumor. "
            "ENDOSCOPIC_ENDONASAL: endoscopic endonasal tumor surgery. "
            "STEREOTACTIC_BIOPSY: stereotactic-guided biopsy. "
            "LITT: laser interstitial thermal therapy. OTHER: other tumor-directed surgery. "
            "NONE_OF_THE_ABOVE: no tumor surgery documented in this note."
        ),
    )
    extent_of_resection: ExtentOfResection = Field(
        default=ExtentOfResection.NOT_AVAILABLE,
        description=(
            "GROSS_TOTAL_RESECTION: GTR / complete / no residual. "
            "NEAR_TOTAL_RESECTION: NTR / >90% with minimal residual. "
            "PARTIAL_RESECTION: subtotal / partial / debulking with residual. "
            "BIOPSY: biopsy only. NOT_AVAILABLE: extent not stated (default)."
        ),
    )
    surgery_date: str | None = Field(
        default=None,
        description="Date of this surgery, ISO YYYY-MM-DD (first-of-period if coarse). Null if not stated.",
    )
    surgery_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for surgery_date. Null when surgery_date is null.",
    )


class SurgeryAnnotation(BaseModel):
    """Surgery annotations from a single clinical note (a list — surgeries repeat).

    """
    surgeries: list[SurgeryMention] = Field(
        default_factory=list,
        description="All tumor-directed surgeries documented in this note; empty list if none.",
    )
