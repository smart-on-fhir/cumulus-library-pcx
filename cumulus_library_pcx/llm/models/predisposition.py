"""Optional germline context for PCX molecular analyses, not a cohort entry rule.
Do not infer inherited predisposition from tumor sequencing or a relative's diagnosis.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .base import SpanAugmentedMention, DatePrecision


class PredispositionStatus(StrEnum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    UNCERTAIN = "UNCERTAIN"
    UNEVALUATED = "UNEVALUATED"


class CancerPredispositionMention(SpanAugmentedMention):
    gene_or_syndrome: str = Field(description="Patient's documented germline gene/syndrome, e.g. SUFU, PTCH1 or TP53; record other findings verbatim.")
    status: PredispositionStatus = Field(default=PredispositionStatus.UNEVALUATED, description="PRESENT for pathogenic/likely pathogenic germline finding or diagnosed syndrome; ABSENT only for explicitly negative testing; UNCERTAIN for VUS, never PRESENT; UNEVALUATED for missing testing.")
    variant_verbatim: str | None = Field(default=None, description="Exact variant and classification if stated.")
    report_date: str | None = Field(default=None, description="Genetics report date, ISO date at supported precision.")
    report_date_precision: DatePrecision | None = Field(default=None, description="Precision for report_date; null if absent.")


class PcxPredispositionAnnotation(BaseModel):
    findings: list[CancerPredispositionMention] = Field(default_factory=list)
