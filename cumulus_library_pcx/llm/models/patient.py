"""PCX timeline anchors and distinct OS/EFS follow-up evidence.

Do not substitute first local diagnosis for original diagnosis, treatment initiation
for enrollment, or last-known-alive for event-free follow-up. Structured dates are
preferred where available; narrative extraction supplies missing context and provenance.
"""
from enum import StrEnum
from pydantic import BaseModel, Field, model_validator
from .base import SpanAugmentedMention, DatePrecision


class TimelineAnchor(StrEnum):
    ORIGINAL_DIAGNOSIS = "ORIGINAL_DIAGNOSIS"
    FIRST_LOCAL_DIAGNOSIS = "FIRST_LOCAL_DIAGNOSIS"
    INITIAL_TUMOR_MRI = "INITIAL_TUMOR_MRI"
    DEFINITIVE_SURGERY = "DEFINITIVE_SURGERY"
    TRIAL_ENROLLMENT = "TRIAL_ENROLLMENT"
    TREATMENT_INITIATION = "TREATMENT_INITIATION"
    INDUCTION_COMPLETION = "INDUCTION_COMPLETION"
    CONSOLIDATION_COMPLETION = "CONSOLIDATION_COMPLETION"


class TimelineAnchorMention(SpanAugmentedMention):
    anchor: TimelineAnchor
    anchor_date: str | None = Field(default=None, description="Date explicitly supporting this anchor, ISO date at supported precision. No proxy substitutions.")
    anchor_date_precision: DatePrecision | None = Field(default=None, description="Precision for anchor_date; null if absent.")
    protocol_name: str | None = Field(default=None, description="Named trial/protocol for enrollment or treatment dates. Enrollment requires explicit documentation.")


class VitalStatus(StrEnum):
    ALIVE = "ALIVE"
    DECEASED = "DECEASED"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class VitalStatusMention(SpanAugmentedMention):
    @model_validator(mode="after")
    def validate_vital_status(self):
        if (self.vital_status != VitalStatus.NONE_OF_THE_ABOVE or self.death_date or self.last_known_alive_date) and not self.has_mention:
            raise ValueError("Vital findings require supporting evidence")
        if self.death_date and self.vital_status != VitalStatus.DECEASED:
            raise ValueError("Death date requires deceased status")
        if self.death_date and self.last_known_alive_date and self.death_date_precision == self.last_known_alive_date_precision == DatePrecision.DAY and self.last_known_alive_date > self.death_date:
            raise ValueError("Alive date cannot follow death")
        return self

    vital_status: VitalStatus = Field(default=VitalStatus.NONE_OF_THE_ABOVE, description="Explicit patient status; administrative records alone do not establish alive status.")
    death_date: str | None = Field(default=None, description="Actual death date, never a later note date. Preserve partial dates with precision.")
    death_date_precision: DatePrecision | None = Field(default=None, description="Precision for death_date; null if absent.")
    last_known_alive_date: str | None = Field(default=None, description="Latest date this document establishes the patient was alive; not automatically the latest encounter or note date.")
    last_known_alive_date_precision: DatePrecision | None = Field(default=None, description="Precision for last_known_alive_date; null if absent.")


class EventFreeFollowUpMention(SpanAugmentedMention):
    event_free: bool | None = Field(default=None, description="True only for explicit follow-up without progression/relapse, secondary malignancy or death; false if such an event is documented. Alive alone is insufficient; null if unknown.")
    assessment_date: str | None = Field(default=None, description="Date of documented event-free status assessment, not extraction date; candidate EFS censoring evidence only.")
    assessment_date_precision: DatePrecision | None = Field(default=None, description="Precision for assessment_date; null if absent.")
    assessment_method: str | None = Field(default=None, description="Clinical follow-up, imaging or other supporting evaluation as stated.")


class PcxPatientTimelineAnnotation(BaseModel):
    anchors: list[TimelineAnchorMention] = Field(default_factory=list)
    vital_status: VitalStatusMention
    event_free_follow_up: list[EventFreeFollowUpMention] = Field(default_factory=list, description="Dated follow-up evidence for downstream EFS ascertainment; retain conflicts across notes.")
