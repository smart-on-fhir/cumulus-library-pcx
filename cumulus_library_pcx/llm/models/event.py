"""Dated disease events for PCX OS/EFS reproduction of ACNS0334.

EFS candidates are progression, recurrence/relapse, secondary malignancy and death.
Remission is a response state, not an adverse EFS event. Do not compute survival or
choose its time origin here. Registered EFS starts at enrollment (NCT00336024);
EHR diagnosis, surgery and treatment dates must remain separate candidate anchors.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .base import SpanAugmentedMention, DatePrecision


class EventType(StrEnum):
    INITIAL_DIAGNOSIS = "INITIAL_DIAGNOSIS"
    RECURRENCE = "RECURRENCE"
    PROGRESSION = "PROGRESSION"
    REMISSION = "REMISSION"
    SECOND_MALIGNANCY = "SECOND_MALIGNANCY"
    SECOND_PRIMARY = "SECOND_PRIMARY"
    DECEASED = "DECEASED"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class SourceOfEventDiagnosis(StrEnum):
    PATHOLOGY = "PATHOLOGY"
    IMAGING = "IMAGING"
    CSF_CYTOLOGY = "CSF_CYTOLOGY"
    CLINICAL = "CLINICAL"
    DEATH_RECORD = "DEATH_RECORD"
    OTHER = "OTHER"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class EventMention(SpanAugmentedMention):
    event_type: EventType = Field(
        default=EventType.NONE_OF_THE_ABOVE,
        description=("Documented event. "
                     "Use clinician-designated progression or relapse; progression can follow partial response. "
                     "SECOND_MALIGNANCY does not require proven treatment causation. "
                     "SECOND_PRIMARY requires explicit designation, not a time/site heuristic. "
                     "Exclude suspected, negated or family-history events."))

    source_of_event_diagnosis: SourceOfEventDiagnosis = Field(
        default=SourceOfEventDiagnosis.NONE_OF_THE_ABOVE,
        description=("Evidence actually establishing this event; "
                     "no arbitrary proximity window or surgery priority."))

    event_date: str | None = Field(
        default=None,
        description=("Earliest date explicitly establishing this event, ISO date at supported precision. "
                     "Do not replace earlier confirmed progression with a later biopsy date. "
                     "For death use actual death date, never the note date."))

    event_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for event_date; null if absent.")

    date_of_progression_mri: str | None = Field(
        default=None,
        description=("Explicit progression MRI date, retained separately from clinical confirmation; "
                     "null for other events."))

    date_of_progression_mri_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for date_of_progression_mri; "
                    "null if absent.")

    confirmation_date: str | None = Field(
        default=None,
        description="Later confirmation date if explicitly distinct from first event evidence.")

    confirmation_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for confirmation_date; null if absent.")


class EventAnnotation(BaseModel):
    events: list[EventMention] = Field(default_factory=list, description="Distinct documented events, including undated events. Deduplication and EFS adjudication occur downstream.")
