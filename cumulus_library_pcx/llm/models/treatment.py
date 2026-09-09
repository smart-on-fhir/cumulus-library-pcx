"""Shared treatment context for PCX exposure and ACNS0334 regimen reconstruction."""
from enum import StrEnum


class TreatmentPhase(StrEnum):
    INDUCTION = "INDUCTION"
    CONSOLIDATION = "CONSOLIDATION"
    POST_CONSOLIDATION = "POST_CONSOLIDATION"
    SALVAGE = "SALVAGE"
    OTHER = "OTHER"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"


class DeliveryStatus(StrEnum):
    ADMINISTERED = "ADMINISTERED"
    PLANNED = "PLANNED"
    HELD = "HELD"
    CANCELLED = "CANCELLED"
    EXPLICITLY_NOT_RECEIVED = "EXPLICITLY_NOT_RECEIVED"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"
