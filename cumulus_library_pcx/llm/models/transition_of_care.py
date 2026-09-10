from enum import StrEnum
from pydantic import BaseModel, Field
from cumulus_library_pcx.llm.models.base import SpanAugmentedMention, DatePrecision

###############################################################################
# How to read this file:
#
# PcxTransitionOfCareAnnotation
# ├── transfer_in: TransferInMention
# │     ├── transfer_in_timing            THIS_ENCOUNTER / PRIOR / PLANNED
# │     ├── transfer_in_date (+precision)  date tumor care began at this institution
# │     └── transfer_in_reason            CLINICAL_REFERRAL / RELOCATION_OR_ACCESS
# ├── diagnosis_setting: DiagnosisSettingMention
# │     ├── diagnosis_setting             EXTERNAL / THIS_INSTITUTION
# │     └── imaging_detected_externally   tumor first seen on outside imaging
# ├── definitive_surgery_setting: DefinitiveSurgerySettingMention
# │     └── surgery_setting               EXTERNAL / THIS_INSTITUTION
# └── prior_therapy_at_entry: PriorTherapyAtEntryMention
#       ├── prior_therapy_exposure        NAIVE / EXPERIENCED
#       └── prior_therapy_modalities      CHEMOTHERAPY / RADIATION / ...
#
# Purpose
# -------
# A transfer patient is a patient whose embryonal brain tumor (medulloblastoma,
# ATRT, ETMR, pineoblastoma or other CNS embryonal tumor) was diagnosed and/or
# treated at another institution before tumor care at this institution began.
# For such a patient the coded record starts mid-course: the first local
# Condition code is the date the diagnosis was *recorded at transfer*, the
# first local MedicationRequest for an induction agent is a continuation and
# not a treatment decision, and the operative report for the definitive
# surgery may not exist locally at all. This model extracts the facts that let
# the phenotype layer tell those apart, so that time zero, age at definitive
# surgery, and treatment initiation are not anchored to a transfer artifact,
# so that the ACNS0334 "newly diagnosed" and "no prior chemotherapy or
# radiation" criteria (PMC12833527) can be assessed rather than assumed, and so
# that referral bias can enter the comparison as a measured covariate.
#
# What this model deliberately does NOT extract
# ---------------------------------------------
# * Which agents were given elsewhere, their doses or cycles. systemic_therapy.py
#   extracts every regimen, agent and administration with dates from the same
#   notes. An administration dated before transfer_in_date is external by
#   construction, so the attribution is a SQL join, not a second extraction.
# * Radiation delivered elsewhere. radiation.py extracts each course with dates.
# * The diagnosis date and the surgery date. diagnosis.py and surgery.py
#   extract those. This model only says WHERE each was established.
# * Transfer out of this institution, shared care with a local oncologist, and
#   referral to another center for proton therapy or stem-cell rescue.
#   Deferred to a later version.
#
# "This institution" in the docstrings below means the institution whose
# clinicians authored the note. HOME_INSTITUTION names it in the per-value
# extraction descriptions so the model can recognize it in the text. PCX is a
# cross-network study: set HOME_INSTITUTION per site before generating schemas.
###############################################################################
HOME_INSTITUTION = "Boston Children's Hospital (BCH)"

###############################################################################
# Transfer in
###############################################################################
class TransferInTiming(StrEnum):
    """
    When, relative to this note's encounter, the patient's tumor care moved to
    this institution from another institution.
    """
    THIS_ENCOUNTER = "THIS_ENCOUNTER"
    PRIOR = "PRIOR"
    PLANNED = "PLANNED"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class TransferInReason(StrEnum):
    """
    Why tumor care moved to this institution. Separates disease-driven referral
    (a confounder: referred patients have higher-risk or progressing disease,
    or need a service the referring center lacks) from moves unrelated to
    disease course.
    """
    CLINICAL_REFERRAL = "CLINICAL_REFERRAL"
    RELOCATION_OR_ACCESS = "RELOCATION_OR_ACCESS"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class TransferInMention(SpanAugmentedMention):
    """
    Transfer of the patient's tumor care INTO this institution from another institution.

    A transfer in means the embryonal tumor was already diagnosed by tissue
    and/or already treated (tumor resection, chemotherapy, or radiation) at
    another institution (another hospital, another pediatric oncology or
    neurosurgery service, or a center abroad) before the patient's tumor care
    at this institution began. Include an accepted inpatient transfer of a
    patient resected at the outside hospital, a patient who started induction
    elsewhere and continues it here, and an outpatient new-patient visit for a
    patient followed elsewhere after treatment.

    The following are NOT a transfer in and must not be extracted:
    * transfer from an outside emergency department or hospital after imaging
      showed a brain mass, when no tissue diagnosis and no tumor-directed
      treatment (other than steroids, shunt or EVD for hydrocephalus) occurred
      there; record that case in diagnosis_setting.imaging_detected_externally
    * transfers within this institution (emergency department to inpatient,
      inpatient to clinic, neurosurgery to oncology)
    * outside labs, imaging, infusions, or radiation done locally at the
      direction of this institution's oncology team (shared care is not a transfer)
    * transfer OUT of this institution, including referral elsewhere for proton
      therapy or stem-cell rescue
    * family history

    Capture the outside institution name in spans when it is stated.
    """
    transfer_in_timing: TransferInTiming = Field(
        default=TransferInTiming.NONE_OF_THE_ABOVE,
        description=(
            f"When the patient's tumor care moved to {HOME_INSTITUTION}, relative to this note. "
            "Choose one. "
            f"THIS_ENCOUNTER: this note documents the patient's first {HOME_INSTITUTION} visit or "
            "admission for the tumor after diagnosis or treatment elsewhere, such as a new patient "
            "visit, a transfer-of-care visit, or an accepted inpatient transfer of a patient already "
            "resected or already on chemotherapy at the outside hospital; "
            f"PRIOR: the transfer to {HOME_INSTITUTION} happened before this encounter and the note "
            "recounts it as history, such as 'transferred care to BCH after induction cycle 2' or "
            "'established care with us following resection at an outside hospital'; "
            "PLANNED: the transfer is proposed or pending and the patient has not yet been seen "
            f"at {HOME_INSTITUTION} for the tumor, such as an outside referral letter or "
            "'will establish oncology care at BCH'; "
            "NONE_OF_THE_ABOVE: no transfer of tumor care into the institution is documented, "
            "or the patient arrived from an outside facility with imaging only and no tissue "
            "diagnosis or tumor-directed treatment elsewhere."
        ),
    )

    transfer_in_date: str | None = Field(
        default=None,
        pattern=r"^\d{4}-\d{2}-\d{2}$",
        description=(
            f"Date the patient's tumor care at {HOME_INSTITUTION} began, in ISO YYYY-MM-DD format "
            "(e.g. 2021-03-15). Emit null when the note does not state the date, including when "
            "transfer_in_timing is THIS_ENCOUNTER and the visit date is not written in the text. "
            "Never emit placeholder text. When only month or year precision is available, use the "
            "first date consistent with it (March 2021 -> 2021-03-01, 2021 -> 2021-01-01) and "
            "record the actual precision in transfer_in_date_precision."
        ),
    )

    transfer_in_date_precision: DatePrecision | None = Field(
        default=None,
        description=(
            "Precision actually supported by the source text for transfer_in_date. "
            "DAY: day, month, and year were explicitly stated; "
            "MONTH: month and year were explicitly stated; "
            "YEAR: only year was explicitly stated; "
            "Use null when transfer_in_date is null."
        ),
    )

    transfer_in_reason: TransferInReason = Field(
        default=TransferInReason.NONE_OF_THE_ABOVE,
        description=(
            f"Documented reason tumor care moved to {HOME_INSTITUTION}. Choose one. "
            "CLINICAL_REFERRAL: the move was driven by the disease or its treatment, such as "
            "referral for pediatric neuro-oncology or neurosurgical expertise, second-look surgery, "
            "high-dose chemotherapy with stem-cell rescue, proton or craniospinal radiation, "
            "enrollment on a protocol such as ACNS0334, progression or relapse, a higher level of "
            "care, or a second opinion sought because of the disease; "
            "RELOCATION_OR_ACCESS: the move was unrelated to disease course, such as the family "
            "moved, insurance changed, the prior provider left, distance or convenience, "
            "or family preference not tied to disease status; "
            "NONE_OF_THE_ABOVE: no reason is documented or the reason does not fit these options."
        ),
    )

###############################################################################
# Diagnosis setting
###############################################################################
class DiagnosisSetting(StrEnum):
    """
    Where the patient's tissue diagnosis of the embryonal tumor was first established.
    """
    EXTERNAL = "EXTERNAL"
    THIS_INSTITUTION = "THIS_INSTITUTION"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class DiagnosisSettingMention(SpanAugmentedMention):
    """
    Institution at which the patient's embryonal tumor diagnosis was first established.

    Diagnosis means the tissue (histologic) diagnosis from the resection or
    biopsy specimen. The diagnosis date itself is extracted by the diagnosis
    model. This mention only records whether that diagnosis was made at this
    institution or elsewhere, which tells the phenotype layer whether the coded
    diagnosis date is an establishment date or a transfer recording, and
    whether the primary pathology report should exist locally.

    Use the initial tissue diagnosis. A later central review, methylation
    classification, molecular subgrouping, or reclassification (for example
    medulloblastoma revised to ETMR or ATRT) at this institution does not make
    an outside diagnosis internal.

    Imaging that first showed the mass is recorded separately in
    imaging_detected_externally. Do not extract family history, negated or
    rule-out tumor, or a suspected/probable/working diagnosis.
    """
    diagnosis_setting: DiagnosisSetting = Field(
        default=DiagnosisSetting.NONE_OF_THE_ABOVE,
        description=(
            "Where the patient's tissue diagnosis was first established. Choose one. "
            "EXTERNAL: the initial resection or biopsy and its pathology were done at another "
            "institution, such as 'resected at CHOP, pathology showed medulloblastoma', "
            "'outside pathology reviewed here and confirmed', or 'diagnosed in Brazil', even if "
            f"later confirmed, subgrouped, or reclassified at {HOME_INSTITUTION}; "
            f"THIS_INSTITUTION: the initial resection or biopsy and pathology were done at "
            f"{HOME_INSTITUTION}, even if the patient was transferred from an outside emergency "
            "department or hospital after imaging showed the mass; "
            "NONE_OF_THE_ABOVE: the note does not say where the tissue diagnosis was established, "
            "or no patient-level embryonal tumor diagnosis is documented."
        ),
    )

    imaging_detected_externally: bool | None = Field(
        default=None,
        description=(
            "True when the note states the brain mass was first identified on imaging (CT or MRI) "
            "at another institution before the patient came here, whether or not surgery was then "
            "done here, such as 'CT at outside ED showed a posterior fossa mass and patient was "
            f"transferred to {HOME_INSTITUTION}'; false when the note states the initial imaging "
            f"was done at {HOME_INSTITUTION}; null when the note does not say where the tumor was "
            "first imaged."
        ),
    )

###############################################################################
# Definitive surgery setting
###############################################################################
class SurgerySetting(StrEnum):
    """
    Where the patient's definitive tumor surgery was performed.
    """
    EXTERNAL = "EXTERNAL"
    THIS_INSTITUTION = "THIS_INSTITUTION"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class DefinitiveSurgerySettingMention(SpanAugmentedMention):
    """
    Institution at which the definitive (initial, maximal) tumor resection was performed.

    ACNS0334 anchors age eligibility on the date of definitive surgery, and the
    trial strata depend on residual disease measured after it. The surgery
    model extracts the operation, its date, extent of resection and residual
    disease; this mention only records where it happened, so the phenotype
    layer knows whether the definitive operative report and postoperative
    imaging are local documents or outside records.

    Definitive surgery is the initial resection intended to remove the tumor.
    A biopsy-only procedure, a shunt or EVD, a second-look resection after
    induction, and surgery for recurrence are not the definitive surgery and
    must not set this value.
    """
    surgery_setting: SurgerySetting = Field(
        default=SurgerySetting.NONE_OF_THE_ABOVE,
        description=(
            "Where the definitive tumor resection was performed. Choose one. "
            "EXTERNAL: the initial resection was performed at another institution, such as "
            "'s/p gross total resection at an outside hospital' or 'resected at Hospital X prior "
            "to transfer'; "
            f"THIS_INSTITUTION: the initial resection was performed at {HOME_INSTITUTION}, "
            "including when the patient was transferred here for the operation after outside imaging; "
            "NONE_OF_THE_ABOVE: the note does not say where the definitive surgery was done, "
            "no resection is documented, or only a biopsy, shunt, or second-look procedure is described."
        ),
    )

###############################################################################
# Prior tumor-directed therapy at entry
###############################################################################
class PriorTherapyExposure(StrEnum):
    """
    Whether the patient had received any tumor-directed chemotherapy or
    radiation before tumor care at this institution began.
    """
    NAIVE = "NAIVE"
    EXPERIENCED = "EXPERIENCED"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class PriorTherapyModality(StrEnum):
    """
    Tumor-directed treatment modalities received elsewhere before care at this
    institution began.
    """
    CHEMOTHERAPY = "CHEMOTHERAPY"
    RADIATION = "RADIATION"
    TUMOR_SURGERY = "TUMOR_SURGERY"
    STEM_CELL_RESCUE = "STEM_CELL_RESCUE"
    STEROIDS_ONLY = "STEROIDS_ONLY"
    OTHER = "OTHER"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class PriorTherapyAtEntryMention(SpanAugmentedMention):
    """
    Tumor-directed therapy received BEFORE the patient's tumor care at this institution began.

    ACNS0334 excluded patients with prior radiotherapy or chemotherapy, with
    steroids allowed. This mention records whether such treatment happened
    elsewhere, so the phenotype layer can separate a patient who is newly
    diagnosed and treatment-naive on arrival from one whose induction, or
    whose relapse treatment, began at another institution.

    Tumor-directed therapy means chemotherapy of any regimen (including a
    partial or single induction cycle elsewhere), radiation of any field or
    dose, and high-dose chemotherapy with stem-cell rescue. Dexamethasone or
    other steroids for edema, a shunt or EVD for hydrocephalus, anticonvulsants
    and supportive care are NOT tumor-directed therapy. Tumor resection is
    recorded as a modality so the sequence is preserved, but surgery alone does
    not make a patient EXPERIENCED.

    Scope is the period before care at this institution. Extract when the note
    ties the exposure to prior or outside care, to the time of transfer, or to
    a treatment history whose starts precede care here. Do not extract from
    statements about therapy started at this institution, and do not extract
    family history.

    Capture the regimen, agent, or modality phrase in spans.
    """
    prior_therapy_exposure: PriorTherapyExposure = Field(
        default=PriorTherapyExposure.NONE_OF_THE_ABOVE,
        description=(
            f"Chemotherapy or radiation exposure before tumor care at {HOME_INSTITUTION} began. "
            "Choose one. "
            "NAIVE: the note states no chemotherapy and no radiation had been given before care here, "
            "such as 'newly diagnosed, treatment-naive', 'no prior therapy', 'has not received any "
            "chemotherapy or radiation', or prior management limited to resection, steroids, shunt or EVD; "
            "EXPERIENCED: at least one chemotherapy administration or radiation course was delivered at "
            f"another institution before tumor care at {HOME_INSTITUTION}, whether completed, "
            "interrupted, or failed, such as 'received induction cycle 1 at outside hospital', "
            "'completed Head Start induction elsewhere', 'craniospinal radiation at Hospital X', or "
            "'transferred after progression on chemotherapy'; "
            "NONE_OF_THE_ABOVE: prior treatment exposure is not documented, or the note does not "
            "distinguish outside therapy from therapy started here."
        ),
    )

    prior_therapy_modalities: list[PriorTherapyModality] = Field(
        default_factory=list,
        description=(
            f"Tumor-directed modalities received elsewhere before care at {HOME_INSTITUTION} began, "
            "one entry per distinct modality documented. "
            "CHEMOTHERAPY: any systemic chemotherapy, including a partial cycle; "
            "RADIATION: any radiation, focal or craniospinal, photon or proton; "
            "TUMOR_SURGERY: resection or biopsy of the tumor; "
            "STEM_CELL_RESCUE: high-dose chemotherapy with autologous stem-cell infusion; "
            "STEROIDS_ONLY: the note states steroids were the only treatment before arrival; "
            "OTHER: a tumor-directed treatment not listed, such as a targeted agent or trial drug; "
            "NONE_OF_THE_ABOVE: no prior modality is documented. "
            "Emit an empty list when prior_therapy_exposure is NONE_OF_THE_ABOVE and nothing is stated."
        ),
    )

###############################################################################
# Aggregated Annotation
#
# This is the top-level structure for the pydantic models used for PCX
# transition-of-care annotations.
###############################################################################
class PcxTransitionOfCareAnnotation(BaseModel):
    """
    Patient-level transition-of-care annotations extracted from a single clinical note.

    Captures whether and when the patient's embryonal tumor care transferred
    into this institution from another institution and why, where the tissue
    diagnosis and the definitive surgery were performed, and whether the
    patient had received chemotherapy or radiation before care here began.
    "This institution" is the institution whose clinicians authored the note.

    Base every value on patient-specific statements in this note. Do not
    extract family history, negated or rule-out tumor, or a
    suspected/probable/working diagnosis. Arrival from an outside emergency
    department with imaging only is not a transfer of care.
    """
    transfer_in: TransferInMention
    diagnosis_setting: DiagnosisSettingMention
    definitive_surgery_setting: DefinitiveSurgerySettingMention
    prior_therapy_at_entry: PriorTherapyAtEntryMention
