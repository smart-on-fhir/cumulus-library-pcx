"""Baseline evaluability and response endpoints for PMC12833527.

Primary endpoint: complete response at end of consolidation in patients with baseline
radiologically or cytologically evaluable disease. Early progression/death remain in
that denominator. Extract assessments, not derived success/failure or response rates.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .base import SpanAugmentedMention, DatePrecision


class ResponseStatus(StrEnum):
    COMPLETE_RESPONSE = "COMPLETE_RESPONSE"
    PARTIAL_RESPONSE = "PARTIAL_RESPONSE"
    STABLE_DISEASE = "STABLE_DISEASE"
    PROGRESSIVE_DISEASE = "PROGRESSIVE_DISEASE"
    NOT_EVALUABLE = "NOT_EVALUABLE"
    INDETERMINATE = "INDETERMINATE"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"


class AssessmentTimepoint(StrEnum):
    BASELINE = "BASELINE"
    DURING_INDUCTION = "DURING_INDUCTION"
    END_INDUCTION = "END_INDUCTION"
    DURING_CONSOLIDATION = "DURING_CONSOLIDATION"
    END_CONSOLIDATION = "END_CONSOLIDATION"
    FOLLOW_UP = "FOLLOW_UP"
    OTHER = "OTHER"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"


class ResponseAssessmentMention(SpanAugmentedMention):
    timepoint: AssessmentTimepoint = Field(default=AssessmentTimepoint.NOT_DOCUMENTED, description="Documented treatment-relative timepoint; do not infer end-consolidation from a remission statement.")
    response: ResponseStatus = Field(default=ResponseStatus.NOT_DOCUMENTED, description="Explicit CR/PR/SD/PD or assessment result. Missing imaging is not CR; do not assign CR from resection alone.")
    radiologically_evaluable: bool | None = Field(default=None, description="Explicit evaluable/measurable disease on imaging at this assessment; null if unknown. Baseline evaluability determines the primary-response denominator.")
    cytologically_evaluable: bool | None = Field(default=None, description="Explicit cytologically evaluable disease at this assessment; null if unknown.")
    assessment_date: str | None = Field(default=None, description="Actual response assessment date, ISO date at supported precision.")
    assessment_date_precision: DatePrecision | None = Field(default=None, description="Precision for assessment_date; null if absent.")
    assessment_method: str | None = Field(default=None, description="MRI, CSF cytology or clinical assessment as documented.")
    review_context: str | None = Field(default=None, description="Local versus central review if stated; preserve disagreements as separate assessments.")


class ResponseAnnotation(BaseModel):
    assessments: list[ResponseAssessmentMention] = Field(default_factory=list, description="All baseline and subsequent assessments. Empty means no assessment extracted, not no disease.")
