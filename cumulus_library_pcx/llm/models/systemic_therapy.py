"""PCX regimen, cycle, dose and stem-cell support evidence for ACNS0334.
The reference uses three induction cycles (cyclophosphamide, etoposide, vincristine,
cisplatin with/without MTX), then three carboplatin/thiotepa consolidation cycles with
stem-cell infusion. Extract actual evidence; never populate drugs/cycles from protocol
name alone or equate a planned protocol dose with administration.

Produces these SQL tables:
SystemicTherapyAnnotation (per note_ref)
├── regimens[]              → pcx__llm_systemic_therapy_regimen
│   └── agents[]            → pcx__llm_systemic_therapy_agent
│       └── administrations[] → pcx__llm_systemic_therapy_administration
├── cycles[]                → pcx__llm_systemic_therapy_cycle
└── stem_cell_infusions[]   → pcx__llm_systemic_therapy_stem_cell_infusion

Coded values are StrEnums, so downstream SQL compares to fixed values instead of parsing
free text. Each coded name keeps a *_verbatim companion with the note's own wording for QA.
"""
from enum import StrEnum
from pydantic import BaseModel, Field, model_validator
from .treatment import TreatmentPhase, DeliveryStatus

from .base import SpanAugmentedMention, DatePrecision


class RxAgentName(StrEnum):
    """Anticancer agent, or one of three supportive drugs that mark a regimen (leucovorin, mesna, dexrazoxane).
    Map brand names, abbreviations and misspellings to the generic member.
    VINCRISTINE: vincristine (Oncovin, VCR).
    CYCLOPHOSPHAMIDE: cyclophosphamide (Cytoxan, CTX).
    CISPLATIN: cisplatin (CDDP).
    CARBOPLATIN: carboplatin (carbo).
    ETOPOSIDE: etoposide (VP-16), intravenous or oral.
    METHOTREXATE: methotrexate (MTX) at any dose or route, including high-dose, intrathecal and intraventricular.
    THIOTEPA: thiotepa.
    TEMOZOLOMIDE: temozolomide (Temodar, TMZ).
    IRINOTECAN: irinotecan (CPT-11).
    TOPOTECAN: topotecan.
    LOMUSTINE: lomustine (CCNU).
    PROCARBAZINE: procarbazine.
    VINBLASTINE: vinblastine.
    CYTARABINE: cytarabine (Ara-C), including intrathecal.
    DOXORUBICIN: doxorubicin (Adriamycin).
    IFOSFAMIDE: ifosfamide.
    BEVACIZUMAB: bevacizumab (Avastin).
    THALIDOMIDE: thalidomide.
    CELECOXIB: celecoxib (Celebrex) given as part of an antitumor regimen.
    FENOFIBRATE: fenofibrate given as part of an antitumor regimen.
    ISOTRETINOIN: isotretinoin (13-cis-retinoic acid).
    VORINOSTAT: vorinostat.
    DABRAFENIB: dabrafenib (Tafinlar).
    TRAMETINIB: trametinib (Mekinist).
    SELUMETINIB: selumetinib (Koselugo).
    TOVORAFENIB: tovorafenib (Ojemda).
    EVEROLIMUS: everolimus (Afinitor).
    INDOXIMOD: indoximod.
    NIVOLUMAB: nivolumab (Opdivo).
    IPILIMUMAB: ipilimumab (Yervoy).
    LEUCOVORIN: leucovorin (folinic acid) rescue, supportive, marks high-dose methotrexate.
    MESNA: mesna, supportive, marks high-dose cyclophosphamide or ifosfamide.
    DEXRAZOXANE: dexrazoxane (Zinecard), supportive, marks anthracycline therapy.
    NONE_OF_THE_ABOVE: another anticancer agent, or a drug class or chemotherapy named without a specific agent."""
    VINCRISTINE = "VINCRISTINE"
    CYCLOPHOSPHAMIDE = "CYCLOPHOSPHAMIDE"
    CISPLATIN = "CISPLATIN"
    CARBOPLATIN = "CARBOPLATIN"
    ETOPOSIDE = "ETOPOSIDE"
    METHOTREXATE = "METHOTREXATE"
    THIOTEPA = "THIOTEPA"
    TEMOZOLOMIDE = "TEMOZOLOMIDE"
    IRINOTECAN = "IRINOTECAN"
    TOPOTECAN = "TOPOTECAN"
    LOMUSTINE = "LOMUSTINE"
    PROCARBAZINE = "PROCARBAZINE"
    VINBLASTINE = "VINBLASTINE"
    CYTARABINE = "CYTARABINE"
    DOXORUBICIN = "DOXORUBICIN"
    IFOSFAMIDE = "IFOSFAMIDE"
    BEVACIZUMAB = "BEVACIZUMAB"
    THALIDOMIDE = "THALIDOMIDE"
    CELECOXIB = "CELECOXIB"
    FENOFIBRATE = "FENOFIBRATE"
    ISOTRETINOIN = "ISOTRETINOIN"
    VORINOSTAT = "VORINOSTAT"
    DABRAFENIB = "DABRAFENIB"
    TRAMETINIB = "TRAMETINIB"
    SELUMETINIB = "SELUMETINIB"
    TOVORAFENIB = "TOVORAFENIB"
    EVEROLIMUS = "EVEROLIMUS"
    INDOXIMOD = "INDOXIMOD"
    NIVOLUMAB = "NIVOLUMAB"
    IPILIMUMAB = "IPILIMUMAB"
    LEUCOVORIN = "LEUCOVORIN"
    MESNA = "MESNA"
    DEXRAZOXANE = "DEXRAZOXANE"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class TreatmentProtocol(StrEnum):
    """Named treatment protocol the patient is treated on or according to, including a modified or protocol-based version (the verbatim field keeps the qualifier).
    ACNS0334: COG ACNS0334, high-dose chemotherapy with or without high-dose methotrexate for young children with high-risk medulloblastoma or embryonal tumors.
    CCG99703: CCG 99703, induction then tandem carboplatin and thiotepa consolidation with stem-cell rescue.
    CCG9921: CCG 9921, infant embryonal tumor induction regimens.
    HEAD_START: Head Start I, II or III, induction then a single myeloablative consolidation with stem-cell rescue.
    HEAD_START_4: Head Start 4, randomized single versus tandem consolidation.
    PBTC_026: PBTC-026, vorinostat and isotretinoin added to induction, consolidation and maintenance.
    SJYC07: St Jude SJYC07, risk-adapted therapy for young children.
    HIT_SKK: German HIT-SKK or HIT 2000 SKK, systemic and intraventricular chemotherapy without radiation.
    ACNS0331: COG ACNS0331, average-risk medulloblastoma.
    ACNS0332: COG ACNS0332, high-risk medulloblastoma.
    ACNS0333: COG ACNS0333, atypical teratoid rhabdoid tumor.
    ACNS1422: COG ACNS1422, reduced therapy for WNT medulloblastoma.
    SJMB12: St Jude SJMB12, molecularly risk-stratified medulloblastoma.
    MEMMAT: MEMMAT metronomic antiangiogenic therapy for relapsed medulloblastoma.
    NONE_OF_THE_ABOVE: another named protocol, no protocol named, or the note states the patient is not treated per a protocol."""
    ACNS0334 = "ACNS0334"
    CCG99703 = "CCG99703"
    CCG9921 = "CCG9921"
    HEAD_START = "HEAD_START"
    HEAD_START_4 = "HEAD_START_4"
    PBTC_026 = "PBTC_026"
    SJYC07 = "SJYC07"
    HIT_SKK = "HIT_SKK"
    ACNS0331 = "ACNS0331"
    ACNS0332 = "ACNS0332"
    ACNS0333 = "ACNS0333"
    ACNS1422 = "ACNS1422"
    SJMB12 = "SJMB12"
    MEMMAT = "MEMMAT"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class CycleCompletionStatus(StrEnum):
    """Explicitly documented status of a treatment cycle; do not infer completion from dates alone.
    PLANNED: planned or scheduled, not yet started.
    STARTED: started and ongoing.
    COMPLETED: completed as planned.
    INTERRUPTED: held, delayed or paused, then resumed or with the outcome not stated.
    DISCONTINUED: stopped before completion and not resumed.
    NONE_OF_THE_ABOVE: status not documented."""
    PLANNED = "PLANNED"
    STARTED = "STARTED"
    COMPLETED = "COMPLETED"
    INTERRUPTED = "INTERRUPTED"
    DISCONTINUED = "DISCONTINUED"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class AdministrationRoute(StrEnum):
    """Route of administration as documented.
    INTRAVENOUS: intravenous (IV).
    ORAL: by mouth or feeding tube (PO, NG, G-tube).
    INTRATHECAL: intrathecal by lumbar puncture (IT).
    INTRAVENTRICULAR: intraventricular, including through an Ommaya reservoir.
    SUBCUTANEOUS: subcutaneous (SC, SQ).
    INTRAMUSCULAR: intramuscular (IM).
    NONE_OF_THE_ABOVE: another route, or route not documented."""
    INTRAVENOUS = "INTRAVENOUS"
    ORAL = "ORAL"
    INTRATHECAL = "INTRATHECAL"
    INTRAVENTRICULAR = "INTRAVENTRICULAR"
    SUBCUTANEOUS = "SUBCUTANEOUS"
    INTRAMUSCULAR = "INTRAMUSCULAR"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class DoseUnit(StrEnum):
    """Unit of dose_amount, including its denominator.
    MG_PER_M2: mg/m2.
    G_PER_M2: g/m2.
    MCG_PER_M2: mcg/m2.
    MG_PER_KG: mg/kg.
    MCG_PER_KG: mcg/kg.
    MG: mg, a flat dose.
    G: g, a flat dose.
    MCG: mcg, a flat dose.
    AUC: carboplatin target area under the curve (mg/mL x min).
    NONE_OF_THE_ABOVE: another unit, or unit not documented."""
    MG_PER_M2 = "MG_PER_M2"
    G_PER_M2 = "G_PER_M2"
    MCG_PER_M2 = "MCG_PER_M2"
    MG_PER_KG = "MG_PER_KG"
    MCG_PER_KG = "MCG_PER_KG"
    MG = "MG"
    G = "G"
    MCG = "MCG"
    AUC = "AUC"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


CYCLE_NUM_DESCRIPTION = (
    "Cycle number exactly as the note numbers it, an integer: 'Cycle 3' is 3, 'Induction cycle 2' "
    "is 2, 'C1D8' is 1, 'maintenance cycle 1' is 1. Do not renumber across phases (phase is "
    "recorded separately). A day or week within a cycle is not a cycle number. Null if no cycle "
    "number is stated."
)
CYCLE_NAME_VERBATIM_DESCRIPTION = "Cycle name or number exactly as written (for QA), such as 'Induction Cycle 2' or 'C1D8'. Null if none."


class TherapyAdministrationMention(SpanAugmentedMention):
    """One documented administration or protocol dose for an agent."""

    @model_validator(mode="after")
    def validate_administration(self):
        if self.delivery_status != DeliveryStatus.NONE_OF_THE_ABOVE and not self.has_mention:
            raise ValueError("Delivery status requires supporting evidence")
        if self.administration_date is not None and self.delivery_status != DeliveryStatus.ADMINISTERED:
            raise ValueError("Actual administration date requires administered status")
        if self.dose_amount is None and self.dose_unit != DoseUnit.NONE_OF_THE_ABOVE:
            raise ValueError("Dose unit requires a numeric dose")
        return self

    delivery_status: DeliveryStatus = Field(default=DeliveryStatus.NONE_OF_THE_ABOVE, description="Delivery status of this dose. ADMINISTERED: actual receipt. PLANNED / HELD / CANCELLED: planned protocol doses, held doses and cancelled orders remain separate from receipt.")
    phase: TreatmentPhase = Field(default=TreatmentPhase.NONE_OF_THE_ABOVE, description="Documented phase of this dose; never infer from drug name alone.")
    cycle_num: int | None = Field(default=None, ge=1, description="Cycle this administration belongs to. " + CYCLE_NUM_DESCRIPTION)
    cycle_day: int | None = Field(
        default=None,
        description=(
            "Day within the cycle on which this dose was given or planned, as written: 'Day 8' is 8, "
            "'C1D15' is 15. Consolidation days are counted from the stem-cell infusion, which is day 0, "
            "so 'Day -3' is -3. A week number is not a day. Null if not stated."
        ),
    )
    cycle_name_verbatim: str | None = Field(default=None, description=CYCLE_NAME_VERBATIM_DESCRIPTION)
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
    dose_unit: DoseUnit = Field(
        default=DoseUnit.NONE_OF_THE_ABOVE,
        description="Unit of dose_amount. NONE_OF_THE_ABOVE when dose_amount is null.",
    )
    route: AdministrationRoute = Field(default=AdministrationRoute.NONE_OF_THE_ABOVE)
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
    """A single anticancer agent documented in treatment planning or delivery. Emit one per distinct
    agent (e.g. vincristine, cisplatin, cyclophosphamide, methotrexate). Also emit leucovorin, mesna and
    dexrazoxane. Do not emit other supportive-care drugs: antiemetics, growth factors (filgrastim,
    pegfilgrastim), antimicrobials and infection prophylaxis, steroids, analgesics, anticonvulsants,
    hydration or electrolytes."""
    delivery_status: DeliveryStatus = Field(default=DeliveryStatus.NONE_OF_THE_ABOVE, description="Receipt of this agent when individual doses are not detailed. Plans do not establish exposure.")
    agent_name: RxAgentName = Field(default=RxAgentName.NONE_OF_THE_ABOVE)
    agent_name_verbatim: str | None = Field(
        default=None,
        description="Agent name exactly as written in the note (for QA), such as 'Cytoxan' or 'HD MTX'. Null if none documented.",
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
    assessed_through_date: str | None = Field(
        default=None,
        description=(
            "Date through which explicit non-receipt or delivery of this agent is assessed, "
            "ISO YYYY-MM-DD. Mainly for EXPLICITLY_NOT_RECEIVED: the note states the agent "
            "was not given as of this date. Never infer from the note date. Null if not stated."
        ),
    )
    assessed_through_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for assessed_through_date. Null when it is null.",
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
    phase: TreatmentPhase = Field(default=TreatmentPhase.NONE_OF_THE_ABOVE, description="Documented phase of this cycle.")
    protocol_name: TreatmentProtocol = Field(default=TreatmentProtocol.NONE_OF_THE_ABOVE, description="Protocol linking this cycle to its regimen, if stated.")
    protocol_name_verbatim: str | None = Field(default=None, description="Protocol name exactly as written (for QA). Null if none.")
    completion_status: CycleCompletionStatus = Field(default=CycleCompletionStatus.NONE_OF_THE_ABOVE)
    interruption_reason: str | None = Field(default=None, description="Reason for interruption/discontinuation only if stated; do not infer toxicity or progression.")
    cycle_num: int | None = Field(default=None, ge=1, description=CYCLE_NUM_DESCRIPTION)
    cycle_name_verbatim: str | None = Field(default=None, description=CYCLE_NAME_VERBATIM_DESCRIPTION)
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
    phase: TreatmentPhase = Field(default=TreatmentPhase.NONE_OF_THE_ABOVE)
    documented_trial_arm: str | None = Field(default=None, description="Explicit randomized arm assignment, if any. Do not infer randomization from observed treatment.")
    protocol_name: TreatmentProtocol = Field(default=TreatmentProtocol.NONE_OF_THE_ABOVE)
    protocol_name_verbatim: str | None = Field(
        default=None,
        description=(
            "Treatment protocol name exactly as written (for QA), such as 'ACNS0334', 'CCG99703', "
            "'modified Head Start'. Null if the note states the patient is not treated per a "
            "protocol, or no protocol is named."
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
    delivery_status: DeliveryStatus = Field(default=DeliveryStatus.NONE_OF_THE_ABOVE)
    phase: TreatmentPhase = Field(default=TreatmentPhase.NONE_OF_THE_ABOVE)
    infusion_date: str | None = Field(default=None, description="Actual stem-cell infusion date, not collection date.")
    infusion_date_precision: DatePrecision | None = Field(default=None, description="Precision for infusion_date; null if absent.")
    cycle_num: int | None = Field(default=None, ge=1, description="Consolidation cycle this infusion rescues, only when documented. " + CYCLE_NUM_DESCRIPTION)
    cycle_name_verbatim: str | None = Field(default=None, description=CYCLE_NAME_VERBATIM_DESCRIPTION)
    cell_source: str | None = Field(default=None, description="Autologous peripheral blood, bone marrow or other documented source.")
    cd34_cells_per_kg: float | None = Field(default=None, ge=0, description="Explicit absolute CD34+ cells/kg; convert a stated multiplier such as 2 x 10^6 to 2000000. Never substitute collected dose for infused dose.")


class SystemicTherapyAnnotation(BaseModel):
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
