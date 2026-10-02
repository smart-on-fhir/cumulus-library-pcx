"""Shared treatment context for PCX exposure and ACNS0334 regimen reconstruction."""
from enum import StrEnum


class TreatmentPhase(StrEnum):
    """Treatment phase as documented.
    INDUCTION: induction.
    CONSOLIDATION: consolidation.
    POST_CONSOLIDATION: post-consolidation.
    SALVAGE: salvage.
    NONE_OF_THE_ABOVE: another documented phase, or phase not documented."""
    INDUCTION = "INDUCTION"
    CONSOLIDATION = "CONSOLIDATION"
    POST_CONSOLIDATION = "POST_CONSOLIDATION"
    SALVAGE = "SALVAGE"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class DeliveryStatus(StrEnum):
    """Delivery status of a treatment.
    ADMINISTERED: administered.
    PLANNED: planned.
    HELD: held.
    CANCELLED: cancelled.
    EXPLICITLY_NOT_RECEIVED: explicitly documented as not received.
    NONE_OF_THE_ABOVE: none of the above."""
    ADMINISTERED = "ADMINISTERED"
    PLANNED = "PLANNED"
    HELD = "HELD"
    CANCELLED = "CANCELLED"
    EXPLICITLY_NOT_RECEIVED = "EXPLICITLY_NOT_RECEIVED"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"
