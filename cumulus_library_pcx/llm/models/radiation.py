"""PCX radiation delivery and timing for ACNS0334 outcome comparisons.
Distinguish initial management, discretionary post-chemotherapy RT and salvage RT.
Capture plans separately from delivery; unknown dose/receipt must not become zero/no RT.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .treatment import TreatmentPhase, DeliveryStatus

from cumulus_library_pcx.llm.models.base import SpanAugmentedMention, DatePrecision


class RadiationMethod(StrEnum):
    """Radiation delivery method used by PCX chart review."""
    PHOTON = "PHOTON"
    PROTON = "PROTON"
    COMBINATION_PROTONS_AND_PHOTONS = "COMBINATION_PROTONS_AND_PHOTONS"
    ELECTRONS = "ELECTRONS"
    THREE_D_CONFORMAL = "THREE_D_CONFORMAL"
    IMRT = "IMRT"
    STEREOTACTIC_RADIOSURGERY = "STEREOTACTIC_RADIOSURGERY"
    GAMMA_KNIFE = "GAMMA_KNIFE"
    BRACHYTHERAPY = "BRACHYTHERAPY"
    OTHER = "OTHER"
    NOT_REPORTED = "NOT_REPORTED"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class RadiationField(StrEnum):
    """Radiation field used by PCX chart review."""
    CRANIOSPINAL = "CRANIOSPINAL"
    CRANIOSPINAL_WITH_FOCAL_BOOST = "CRANIOSPINAL_WITH_FOCAL_BOOST"
    FOCAL_TUMOR_BED = "FOCAL_TUMOR_BED"
    WHOLE_VENTRICULAR_WITH_FOCAL_BOOST = "WHOLE_VENTRICULAR_WITH_FOCAL_BOOST"
    OTHER = "OTHER"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class RadiationUnits(StrEnum):
    """Radiation dose units used by PCX chart review."""
    CGY = "CGY"
    GY = "GY"
    CGE = "CGE"


class RadiationRoundMention(SpanAugmentedMention):
    """A single radiation round: method, field, dates, and doses. Emit one per distinct
    course of radiation documented in this note. Leave dose fields null when not stated or
    not applicable (metastatic-site doses require metastasis; whole-ventricular is only for
    germ-cell tumors)."""
    delivery_status: DeliveryStatus = Field(default=DeliveryStatus.NOT_DOCUMENTED, description="ADMINISTERED requires delivered RT; PLANNED or HELD is not exposure. Explicit non-receipt must be stated, not inferred from silence.")
    phase: TreatmentPhase = Field(default=TreatmentPhase.NOT_DOCUMENTED)
    indication: str | None = Field(default=None, description="Initial treatment, post-chemotherapy residual/metastatic disease, salvage after relapse or other documented indication. Do not infer from dose.")
    assessed_through_date: str | None = Field(default=None, description="Date through which explicit non-receipt or delivery is assessed.")
    assessed_through_date_precision: DatePrecision | None = Field(default=None, description="Precision for assessed_through_date; null if absent.")
    dose_verbatim: str | None = Field(default=None, description="Exact delivered dose(s), field(s) and units; preserve mixed units here instead of assigning incorrect shared units.")
    radiation_method: RadiationMethod = Field(
        default=RadiationMethod.NONE_OF_THE_ABOVE,
        description=(
            "Delivery method/energy. PHOTON / PROTON / COMBINATION_PROTONS_AND_PHOTONS / "
            "ELECTRONS by modality. THREE_D_CONFORMAL: 3D conformal. IMRT: intensity-modulated. "
            "STEREOTACTIC_RADIOSURGERY: SRS. GAMMA_KNIFE. BRACHYTHERAPY. OTHER: another method. "
            "NOT_REPORTED: radiation given but method not stated. NONE_OF_THE_ABOVE: method not established; not evidence of non-receipt."
        ),
    )
    radiation_field: RadiationField = Field(
        default=RadiationField.NONE_OF_THE_ABOVE,
        description=(
            "Treated field. CRANIOSPINAL: CSI without a documented boost. CRANIOSPINAL_WITH_FOCAL_BOOST: craniospinal irradiation plus a "
            "tumor-bed boost. FOCAL_TUMOR_BED: focal/involved-field only. "
            "WHOLE_VENTRICULAR_WITH_FOCAL_BOOST: whole-ventricular plus boost (germ-cell). "
            "OTHER: another field. NONE_OF_THE_ABOVE: field not stated."
        ),
    )
    radiation_start_date: str | None = Field(
        default=None, description="Round start date, ISO YYYY-MM-DD. Null if not stated.",
    )
    radiation_start_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for radiation_start_date. Null when it is null.",
    )
    radiation_end_date: str | None = Field(
        default=None, description="Round end date, ISO YYYY-MM-DD. Null if not stated.",
    )
    radiation_end_date_precision: DatePrecision | None = Field(
        default=None, description="Precision for radiation_end_date. Null when it is null.",
    )
    focal_dose_to_primary_site: float | None = Field(
        default=None, ge=0,
        description="Focal boost dose to the primary tumor site (numeric, in dose_units). Null if not stated.",
    )
    total_dose_to_primary_site: float | None = Field(
        default=None, ge=0,
        description="Total dose to the primary site (focal + craniospinal/whole-ventricular if given). Null if not stated.",
    )
    focal_dose_to_metastatic_site: float | None = Field(
        default=None, ge=0,
        description="Focal boost dose to a metastatic site (only if radiation given to metastasis). Null otherwise.",
    )
    total_dose_to_metastatic_site: float | None = Field(
        default=None, ge=0,
        description="Total dose to a metastatic site (only if radiation given to metastasis). Null otherwise.",
    )
    craniospinal_dose: float | None = Field(
        default=None, ge=0,
        description="Craniospinal-axis dose (only if craniospinal radiation given). Null otherwise.",
    )
    whole_ventricular_dose: float | None = Field(
        default=None, ge=0,
        description="Whole-ventricular dose (only for germ-cell tumors). Null otherwise.",
    )
    dose_units: RadiationUnits | None = Field(
        default=None,
        description=(
            "Units for the dose fields in this round. CGY: centigray. GY: gray (=100 cGy). "
            "CGE: cobalt gray equivalent (proton). Null if no dose is stated or units are mixed; preserve mixed units in dose_verbatim."
        ),
    )


class PcxRadiationAnnotation(BaseModel):
    """Radiation-therapy annotations from a single clinical note (a list — rounds repeat).

    """
    radiation_rounds: list[RadiationRoundMention] = Field(
        default_factory=list,
        description="All radiation rounds documented in this note; empty list if none.",
    )
