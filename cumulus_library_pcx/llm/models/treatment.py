"""Shared treatment context for PCX exposure and ACNS0334 regimen reconstruction."""
from enum import StrEnum


class TreatmentPhase(StrEnum):
    """Treatment phase as documented.
    INDUCTION: induction.
    CONSOLIDATION: consolidation.
    POST_CONSOLIDATION: post-consolidation.
    SALVAGE: salvage.
    OTHER: another documented phase.
    NOT_DOCUMENTED: phase not documented."""
    INDUCTION = "INDUCTION"
    CONSOLIDATION = "CONSOLIDATION"
    POST_CONSOLIDATION = "POST_CONSOLIDATION"
    SALVAGE = "SALVAGE"
    OTHER = "OTHER"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"


class DeliveryStatus(StrEnum):
    """Delivery status of a treatment.
    ADMINISTERED: administered.
    PLANNED: planned.
    HELD: held.
    CANCELLED: cancelled.
    EXPLICITLY_NOT_RECEIVED: explicitly documented as not received.
    NOT_DOCUMENTED: delivery status not documented."""
    ADMINISTERED = "ADMINISTERED"
    PLANNED = "PLANNED"
    HELD = "HELD"
    CANCELLED = "CANCELLED"
    EXPLICITLY_NOT_RECEIVED = "EXPLICITLY_NOT_RECEIVED"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"
