"""Baseline evaluability and response endpoints for PMC12833527.

Primary endpoint: complete response at end of consolidation in patients with baseline
radiologically or cytologically evaluable disease. Early progression/death remain in
that denominator. Extract assessments, not derived success/failure or response rates.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .base import SpanAugmentedMention, DatePrecision


class ResponseStatus(StrEnum):
    """Response assessment result as explicitly documented.
    COMPLETE_RESPONSE: complete response (CR).
    PARTIAL_RESPONSE: partial response (PR).
    STABLE_DISEASE: stable disease (SD).
    PROGRESSIVE_DISEASE: progressive disease (PD).
    NONE_OF_THE_ABOVE: not evaluable, indeterminate, or no response documented."""
    COMPLETE_RESPONSE = "COMPLETE_RESPONSE"
    PARTIAL_RESPONSE = "PARTIAL_RESPONSE"
    STABLE_DISEASE = "STABLE_DISEASE"
    PROGRESSIVE_DISEASE = "PROGRESSIVE_DISEASE"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class AssessmentTimepoint(StrEnum):
    """Treatment-relative timepoint of a response assessment as documented.
    BASELINE: before treatment starts.
    DURING_INDUCTION: during induction.
    END_INDUCTION: at end of induction.
    DURING_CONSOLIDATION: during consolidation.
    END_CONSOLIDATION: at end of consolidation.
    FOLLOW_UP: after treatment completion.
    NONE_OF_THE_ABOVE: another timepoint, or timepoint not documented."""
    BASELINE = "BASELINE"
    DURING_INDUCTION = "DURING_INDUCTION"
    END_INDUCTION = "END_INDUCTION"
    DURING_CONSOLIDATION = "DURING_CONSOLIDATION"
    END_CONSOLIDATION = "END_CONSOLIDATION"
    FOLLOW_UP = "FOLLOW_UP"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"

class ResponseAssessmentMention(SpanAugmentedMention):
    timepoint: AssessmentTimepoint = Field(
        default=AssessmentTimepoint.NONE_OF_THE_ABOVE,
        description="Documented treatment-relative timepoint; "
                    "do not infer end-consolidation from a remission statement."
    )
    response: ResponseStatus = Field(
        default=ResponseStatus.NONE_OF_THE_ABOVE,
        description="Explicit CR/PR/SD/PD or assessment result. "
                    "Missing imaging is not CR; do not assign CR from resection alone."
    )
    radiologically_evaluable: bool | None = Field(
        default=None,
        description="Explicit evaluable/measurable disease on imaging at this assessment; "
                    "null if unknown. Baseline evaluability determines the primary-response denominator."
    )
    cytologically_evaluable: bool | None = Field(
        default=None,
        description="Explicit cytologically evaluable disease at this assessment; null if unknown."
    )
    assessment_date: str | None = Field(
        default=None,
        description="Actual response assessment date, ISO date at supported precision."
    )
    assessment_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for assessment_date; "
                    "null if absent."
    )


class ResponseAnnotation(BaseModel):
    assessments: list[ResponseAssessmentMention] = Field(
        default_factory=list,
        description="All baseline and subsequent assessments. "
                      "Empty means no assessment extracted, not no disease."
    )
