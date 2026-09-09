"""PCX regimen, cycle, dose and stem-cell support evidence for ACNS0334.
The reference uses three induction cycles (cyclophosphamide, etoposide, vincristine,
cisplatin with/without MTX), then three carboplatin/thiotepa consolidation cycles with
stem-cell infusion. Extract actual evidence; never populate drugs/cycles from protocol
name alone or equate a planned protocol dose with administration.
"""
from pydantic import BaseModel, Field, model_validator
from .treatment import TreatmentPhase, DeliveryStatus

from cumulus_library_pcx.llm.models.base import SpanAugmentedMention, DatePrecision


class TherapyAdministrationMention(SpanAugmentedMention):
    """One documented administration or protocol dose for an agent."""

    @model_validator(mode="after")
    def validate_administration(self):
        if self.delivery_status != DeliveryStatus.NOT_DOCUMENTED and not self.has_mention:
            raise ValueError("Delivery status requires supporting evidence")
        if self.administration_date is not None and self.delivery_status != DeliveryStatus.ADMINISTERED:
            raise ValueError("Actual administration date requires administered status")
        if self.dose_amount is None and self.dose_unit is not None:
            raise ValueError("Dose unit requires a numeric dose")
        return self

    delivery_status: DeliveryStatus = Field(default=DeliveryStatus.NOT_DOCUMENTED, description="ADMINISTERED requires actual receipt. Planned protocol doses, held doses and cancelled orders remain separate.")
    phase: TreatmentPhase = Field(default=TreatmentPhase.NOT_DOCUMENTED, description="Documented phase of this dose; never infer from drug name alone.")
    cycle_name: str | None = Field(default=None, description="Cycle linked to this administration, if stated.")
    administration_date: str | None = Field(
        default=None,
        description="Administration date, ISO YYYY-MM-DD. Null if not stated.",
    )
    administration_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for administration_date. Null when it is null.",
    )
    dose_amount: float | None = Field(
        default=None,
        ge=0,
        description=(
            "Numeric dose amount as documented. Use the per-body-surface-area amount "
            "when the note gives g/m2 or mg/m2; otherwise use the administered amount. "
            "Null if no numeric dose is stated."
        ),
    )
    dose_unit: str | None = Field(
        default=None,
        description=(
            "Dose unit exactly as written, including denominator when present, such "
            "as 'g/m2', 'mg/m2', or 'mg/kg'. Null when dose_amount is null."
        ),
    )
    route: str | None = Field(
        default=None,
        description=(
            "Administration route as written, such as intravenous, intrathecal, or "
            "oral. Null if not stated."
        ),
    )
    high_dose_methotrexate_explicit_bool: bool | None = Field(
        default=None,
        description=(
            "True only when this administration is explicitly called high-dose "
            "methotrexate. False only when explicitly characterized as not high-dose; "
            "null when unknown. Numeric dose-based classification occurs downstream. "
            "This label does not establish receipt; inspect delivery_status."
        ),
    )


class TherapyAgentMention(SpanAugmentedMention):
    """A single systemic agent documented in treatment planning or delivery. Emit one per distinct
    agent (e.g. vincristine, cisplatin, cyclophosphamide, methotrexate)."""
    delivery_status: DeliveryStatus = Field(default=DeliveryStatus.NOT_DOCUMENTED, description="Receipt of this agent when individual doses are not detailed. Plans do not establish exposure.")
    agent_name: str | None = Field(
        default=None,
        description="Therapeutic agent name as written (generic preferred). Null if none documented.",
    )
    therapy_start_date: str | None = Field(
        default=None, description="Agent start date, ISO YYYY-MM-DD. Null if not stated.",
    )
    therapy_start_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for therapy_start_date. Null when it is null.",
    )
    therapy_stop_date: str | None = Field(
        default=None, description="Agent stop date, ISO YYYY-MM-DD. Null if not stated.",
    )
    therapy_stop_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for therapy_stop_date. Null when it is null.",
    )
    administrations: list[TherapyAdministrationMention] = Field(
        default_factory=list,
        description=(
            "All distinct dated administrations or explicitly stated protocol doses "
            "for this agent in the document. Empty when no administration-level detail "
            "is stated."
        ),
    )


class MedicalTherapyCycleMention(SpanAugmentedMention):
    """A named or numbered chemotherapy cycle (for protocols that use cycles)."""
    phase: TreatmentPhase = Field(default=TreatmentPhase.NOT_DOCUMENTED, description="Documented induction, consolidation or salvage phase.")
    protocol_name_verbatim: str | None = Field(default=None, description="Protocol linking this cycle to its regimen if stated.")
    completion_status: str | None = Field(default=None, description="Explicit planned, started, completed, interrupted or discontinued cycle status.")
    interruption_reason: str | None = Field(default=None, description="Reason for interruption/discontinuation only if stated; do not infer toxicity or progression.")
    cycle_name: str | None = Field(
        default=None,
        description="Cycle name or number as written (e.g. 'Induction Cycle 2', 'Cycle 3'). Null if none.",
    )
    cycle_start_date: str | None = Field(
        default=None, description="Cycle start date, ISO YYYY-MM-DD. Null if not stated.",
    )
    cycle_start_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for cycle_start_date. Null when it is null.",
    )
    cycle_stop_date: str | None = Field(
        default=None, description="Cycle stop date, ISO YYYY-MM-DD. Null if not stated.",
    )
    cycle_stop_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for cycle_stop_date. Null when it is null.",
    )


class MedicalTherapyRegimenMention(SpanAugmentedMention):
    """A medical-therapy (chemotherapy) regimen: the protocol the patient is treated on or
    in accordance with, its start/stop, and the agents it comprises. Emit one per distinct
    regimen documented in this note."""
    phase: TreatmentPhase = Field(default=TreatmentPhase.NOT_DOCUMENTED)
    documented_trial_arm: str | None = Field(default=None, description="Explicit randomized arm assignment, if any. Do not infer randomization from observed treatment.")
    protocol_name_verbatim: str | None = Field(
        default=None,
        description=(
            "Treatment protocol name as written (e.g. 'ACNS0334', 'CCG99703', 'Head Start'). Null if the note states the "
            "patient is not treated per a protocol, or no protocol is named."
        ),
    )
    regimen_start_date: str | None = Field(
        default=None, description="Regimen start date, ISO YYYY-MM-DD. Null if not stated.",
    )
    regimen_start_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for regimen_start_date. Null when it is null.",
    )
    regimen_stop_date: str | None = Field(
        default=None, description="Regimen stop date, ISO YYYY-MM-DD. Null if not stated.",
    )
    regimen_stop_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for regimen_stop_date. Null when it is null.",
    )
    agents: list[TherapyAgentMention] = Field(
        default_factory=list,
        description="Agents documented for this regimen; inspect delivery_status to establish receipt, not the protocol name.",
    )


class StemCellInfusionMention(SpanAugmentedMention):
    delivery_status: DeliveryStatus = Field(default=DeliveryStatus.NOT_DOCUMENTED)
    phase: TreatmentPhase = Field(default=TreatmentPhase.NOT_DOCUMENTED)
    infusion_date: str | None = Field(default=None, description="Actual stem-cell infusion date, not collection date.")
    infusion_date_precision: DatePrecision | None = Field(default=None, description="Precision for infusion_date; null if absent.")
    cycle_name: str | None = Field(default=None, description="Associated consolidation cycle, only when documented.")
    cell_source: str | None = Field(default=None, description="Autologous peripheral blood, bone marrow or other documented source.")
    cd34_cells_per_kg: float | None = Field(default=None, ge=0, description="Explicit absolute CD34+ cells/kg; convert a stated multiplier such as 2 x 10^6 to 2000000. Never substitute collected dose for infused dose.")


class PcxSystemicTherapyAnnotation(BaseModel):
    """Systemic-therapy annotations from a single clinical note.

    """
    regimens: list[MedicalTherapyRegimenMention] = Field(
        default_factory=list,
        description="All medical-therapy regimens documented in this note; empty list if none.",
    )
    stem_cell_infusions: list[StemCellInfusionMention] = Field(default_factory=list, description="Documented stem-cell rescue/infusion events, separate from collection and plans.")
    cycles: list[MedicalTherapyCycleMention] = Field(
        default_factory=list,
        description="All named/numbered therapy cycles documented in this note; empty list if none.",
    )
