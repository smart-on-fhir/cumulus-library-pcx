"""PCX diagnosis evidence for reproducing ACNS0334 (PMC12833527).
Prioritize medulloblastoma, including Group 3, while retaining ETMR, pineoblastoma,
and historical sPNET diagnoses for the paper's broader embryonal cohort. ATRT is an
exclusion/reclassification finding, never the required diagnosis. Extract the patient's
confirmed diagnosis; preserve historical and revised diagnoses without silently mapping
legacy PNET to a modern molecular entity. Molecular provenance lives in molecular.py."""
from enum import StrEnum
from pydantic import BaseModel, Field

from cumulus_library_pcx.llm.models.base import SpanAugmentedMention, DatePrecision


class DiseaseSubtype(StrEnum):
    """Embryonal diagnoses, including exclusions and historical classifications."""
    ATRT = "ATRT"
    MEDULLOBLASTOMA = "MEDULLOBLASTOMA"
    ETMR = "ETMR"
    PINEOBLASTOMA = "PINEOBLASTOMA"
    LEGACY_SPNET = "LEGACY_SPNET"
    OTHER_CNS_EMBRYONAL = "OTHER_CNS_EMBRYONAL"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class MedulloblastomaHistology(StrEnum):
    """WHO histologic pattern of medulloblastoma (distinct from molecular group)."""
    CLASSIC = "CLASSIC"
    DESMOPLASTIC_NODULAR = "DESMOPLASTIC_NODULAR"
    EXTENSIVE_NODULARITY_MBEN = "EXTENSIVE_NODULARITY_MBEN"
    LARGE_CELL_ANAPLASTIC = "LARGE_CELL_ANAPLASTIC"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class CnsDiagnosisCategory(StrEnum):
    """Broad documented CNS diagnosis family."""
    HIGH_GRADE_GLIOMA = "HIGH_GRADE_GLIOMA"
    LOW_GRADE_GLIOMA = "LOW_GRADE_GLIOMA"
    EPENDYMOMA = "EPENDYMOMA"
    MEDULLOBLASTOMA = "MEDULLOBLASTOMA"
    ATRT = "ATRT"
    ETMR = "ETMR"
    PINEOBLASTOMA = "PINEOBLASTOMA"
    LEGACY_SPNET = "LEGACY_SPNET"
    OTHER_CNS_EMBRYONAL = "OTHER_CNS_EMBRYONAL"
    CNS_GERM_CELL_TUMOR = "CNS_GERM_CELL_TUMOR"
    GLIONEURONAL_AND_NEURONAL = "GLIONEURONAL_AND_NEURONAL"
    CRANIOPHARYNGIOMA = "CRANIOPHARYNGIOMA"
    CHOROID_PLEXUS_TUMOR = "CHOROID_PLEXUS_TUMOR"
    CNS_SARCOMA = "CNS_SARCOMA"
    OTHER = "OTHER"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class CnsIntegratedDiagnosis(StrEnum):
    """Documented integrated diagnosis; retain exact wording for reclassification."""
    ATRT_SHH = "ATRT_SHH"
    ATRT_MYC = "ATRT_MYC"
    ATRT_TYR = "ATRT_TYR"
    ATRT_NOS = "ATRT_NOS"
    MB_WNT = "MB_WNT"
    MB_SHH_TP53_WILDTYPE = "MB_SHH_TP53_WILDTYPE"
    MB_SHH_TP53_MUTANT = "MB_SHH_TP53_MUTANT"
    MB_NON_WNT_NON_SHH = "MB_NON_WNT_NON_SHH"
    MB_GROUP_3 = "MB_GROUP_3"
    MB_GROUP_4 = "MB_GROUP_4"
    MB_NOS = "MB_NOS"
    ETMR = "ETMR"
    PINEOBLASTOMA = "PINEOBLASTOMA"
    LEGACY_SPNET = "LEGACY_SPNET"
    OTHER_CNS_EMBRYONAL = "OTHER_CNS_EMBRYONAL"
    OTHER = "OTHER"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class ChangMStage(StrEnum):
    """Chang metastasis stage (Chang M-stage). Direct-extraction fallback; the derived
    stage is to be adjudicated downstream from the metastasis.py staging inputs."""
    M0 = "M0"
    M1 = "M1"
    M2 = "M2"
    M3 = "M3"
    M4 = "M4"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class TumorLocation(StrEnum):
    """Primary tumor site, grouped into decision-relevant clinical regions. Use
    tumor_location_verbatim to preserve the exact documented site phrase."""
    CEREBELLUM_POSTERIOR_FOSSA = "CEREBELLUM_POSTERIOR_FOSSA"
    FOURTH_VENTRICLE = "FOURTH_VENTRICLE"
    CEREBRAL_HEMISPHERE = "CEREBRAL_HEMISPHERE"
    DEEP_SUPRATENTORIAL = "DEEP_SUPRATENTORIAL"
    SUPRASELLAR_PITUITARY = "SUPRASELLAR_PITUITARY"
    PINEAL = "PINEAL"
    BRAINSTEM = "BRAINSTEM"
    VENTRICLES_OTHER = "VENTRICLES_OTHER"
    SPINAL_CORD = "SPINAL_CORD"
    OPTIC_PATHWAY = "OPTIC_PATHWAY"
    MENINGES_DURA = "MENINGES_DURA"
    OTHER = "OTHER"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class Laterality(StrEnum):
    """Tumor side relative to the midline."""
    LEFT = "LEFT"
    RIGHT = "RIGHT"
    BILATERAL = "BILATERAL"
    MIDLINE = "MIDLINE"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class DiseaseSubtypeMention(SpanAugmentedMention):
    """The patient's documented CNS embryonal tumor diagnosis. Choose the single best
    subtype supported by pathology/molecular text in THIS note. Do not extract negated,
    rule-out, suspected/probable, or family-history diagnoses."""
    disease_subtype: DiseaseSubtype = Field(
        default=DiseaseSubtype.NONE_OF_THE_ABOVE,
        description=(
            "Documented diagnosis using only evidence from this note. Choose exactly one. "
            "ATRT: atypical teratoid/rhabdoid tumor, AT/RT, malignant rhabdoid tumor of the "
            "CNS. Record ATRT as an exclusion/reclassification; do not infer it from a marker alone. "
            "MEDULLOBLASTOMA: medulloblastoma of any histology or molecular group (WNT, SHH, "
            "Group 3, Group 4), incl. medullomyoblastoma and MBEN. "
            "ETMR: embryonal tumor with multilayered rosettes. PINEOBLASTOMA: pineoblastoma. "
            "LEGACY_SPNET: historical supratentorial PNET/CNS-PNET without a modern diagnosis. "
            "OTHER_CNS_EMBRYONAL: other embryonal CNS tumor or embryonal tumor NOS. "
            "NONE_OF_THE_ABOVE: no embryonal-tumor diagnosis is documented in this note."
        ),
    )


class MedulloblastomaHistologyMention(SpanAugmentedMention):
    """Histologic pattern when the diagnosis is medulloblastoma. Leave NONE_OF_THE_ABOVE if
    the histologic pattern is not stated or the tumor is not a medulloblastoma."""
    histology: MedulloblastomaHistology = Field(
        default=MedulloblastomaHistology.NONE_OF_THE_ABOVE,
        description=(
            "CLASSIC: classic medulloblastoma. "
            "DESMOPLASTIC_NODULAR: desmoplastic/nodular. "
            "EXTENSIVE_NODULARITY_MBEN: medulloblastoma with extensive nodularity (MBEN). "
            "LARGE_CELL_ANAPLASTIC: large-cell and/or anaplastic. "
            "NONE_OF_THE_ABOVE: histologic pattern not stated or not a medulloblastoma."
        ),
    )


class CnsDiagnosisCategoryMention(SpanAugmentedMention):
    """Broad diagnosis family, preserving non-medulloblastoma and exclusion diagnoses."""
    cns_diagnosis_category: CnsDiagnosisCategory = Field(
        default=CnsDiagnosisCategory.NONE_OF_THE_ABOVE,
        description=(
            "The broad diagnosis family. "
            "MEDULLOBLASTOMA: any medulloblastoma. ATRT: atypical teratoid/rhabdoid tumor. "
            "ETMR / PINEOBLASTOMA / LEGACY_SPNET: the corresponding named diagnosis. "
            "OTHER_CNS_EMBRYONAL: CNS neuroblastoma or embryonal tumor NOS. "
            "HIGH_GRADE_GLIOMA / LOW_GRADE_GLIOMA / EPENDYMOMA / CNS_GERM_CELL_TUMOR / "
            "GLIONEURONAL_AND_NEURONAL / CRANIOPHARYNGIOMA / CHOROID_PLEXUS_TUMOR / CNS_SARCOMA: "
            "the corresponding family. OTHER: a CNS tumor family not listed. "
            "NONE_OF_THE_ABOVE: category not documented."
        ),
    )


class CnsIntegratedDiagnosisMention(SpanAugmentedMention):
    """The WHO-CNS5 integrated diagnosis (histology + molecular). Choose the embryonal
    subtype when documented, and ALWAYS copy the exact integrated-diagnosis phrase into
    integrated_diagnosis_verbatim to preserve the original report wording.
    If the note uses a deprecated pre-CNS5 name for this tumor (e.g. 'PNET', 'cerebellar
    sarcoma'), also record it verbatim in historical_diagnosis_term for legacy-term crosswalk."""
    integrated_diagnosis: CnsIntegratedDiagnosis = Field(
        default=CnsIntegratedDiagnosis.NONE_OF_THE_ABOVE,
        description=(
            "Integrated diagnosis, embryonal-focused. "
            "ATRT_SHH / ATRT_MYC / ATRT_TYR: ATRT with the named methylation subgroup. "
            "ATRT_NOS: ATRT without a stated subgroup. "
            "MB_WNT: medulloblastoma WNT-activated. "
            "MB_SHH_TP53_WILDTYPE / MB_SHH_TP53_MUTANT: SHH-activated by TP53 status. "
            "MB_NON_WNT_NON_SHH: non-WNT/non-SHH (use when Group 3/4 not distinguished). "
            "MB_GROUP_3 / MB_GROUP_4: the named group. MB_NOS: medulloblastoma NOS/NEC. "
            "ETMR / PINEOBLASTOMA / LEGACY_SPNET: the named entity or unresolved historical diagnosis. "
            "OTHER_CNS_EMBRYONAL: other embryonal integrated diagnosis. "
            "OTHER: an integrated diagnosis outside the embryonal set (record the phrase in "
            "integrated_diagnosis_verbatim). NONE_OF_THE_ABOVE: not documented."
        ),
    )
    integrated_diagnosis_verbatim: str | None = Field(
        default=None,
        description=(
            "The exact WHO-CNS5 integrated-diagnosis phrase as written in the note (e.g. "
            "'Medulloblastoma, SHH-activated and TP53-mutant'). Null if not stated."
        ),
    )
    historical_diagnosis_term: str | None = Field(
        default=None,
        description=(
            "A deprecated or legacy (pre-WHO-CNS5) diagnosis term the note uses for THIS tumor "
            "-- e.g. 'PNET', 'CNS-PNET', 'supratentorial PNET', 'cerebellar sarcoma', "
            "'medulloblastoma variant'. Capture the exact historical phrase verbatim so a "
            "downstream crosswalk can review it against a current diagnosis; do not infer a modern entity from a legacy term. Null "
            "when the note uses only current integrated-diagnosis terminology, or no such term "
            "is stated. Do not record family-history, negated, or rule-out terms."
        ),
    )


class TumorLocationMention(SpanAugmentedMention):
    """Primary anatomic site of the tumor at this event. Extract from the imaging
    impression first, then the pathology gross description. Also copy the exact site phrase
    to tumor_location_verbatim for review."""
    location: TumorLocation = Field(
        default=TumorLocation.NONE_OF_THE_ABOVE,
        description=(
            "CEREBELLUM_POSTERIOR_FOSSA: cerebellum / posterior fossa (classic MB site). "
            "FOURTH_VENTRICLE: fourth ventricle. "
            "CEREBRAL_HEMISPHERE: frontal/temporal/parietal/occipital lobe or convexity "
            "(common for ATRT). "
            "DEEP_SUPRATENTORIAL: thalamus, basal ganglia, corpus callosum, hippocampus. "
            "SUPRASELLAR_PITUITARY: suprasellar/hypothalamic/pituitary/sellar region. "
            "PINEAL: pineal region. BRAINSTEM: midbrain/tectum, pons, or medulla. "
            "VENTRICLES_OTHER: lateral/third ventricle or aqueduct. SPINAL_CORD: any spinal "
            "level, conus, or cauda equina. OPTIC_PATHWAY: optic nerve/chiasm/pathway. "
            "MENINGES_DURA: meningeal/dural site. OTHER: a site not listed. "
            "NONE_OF_THE_ABOVE: site not stated."
        ),
    )
    tumor_location_verbatim: str | None = Field(
        default=None,
        description="Exact site phrase from the note (e.g. 'left cerebellar hemisphere'). Null if not stated.",
    )


class LateralityMention(SpanAugmentedMention):
    """Side of the primary tumor relative to midline."""
    laterality: Laterality = Field(
        default=Laterality.NONE_OF_THE_ABOVE,
        description=(
            "LEFT / RIGHT: lateralized to that hemisphere/side. BILATERAL: both sides. "
            "MIDLINE: midline/crossing midline (e.g. vermis, suprasellar, brainstem). "
            "NONE_OF_THE_ABOVE: laterality not stated."
        ),
    )


class ChangMStageMention(SpanAugmentedMention):
    """Documented Chang metastasis stage (M-stage) at diagnosis/staging, when stated
    directly. The derived stage is to be adjudicated downstream from the metastasis.py
    inputs; this captures an explicitly written stage."""
    chang_m_stage: ChangMStage = Field(
        default=ChangMStage.NONE_OF_THE_ABOVE,
        description=(
            "M0: no metastasis (localized). M1: positive CSF cytology only. "
            "M2: intracranial metastasis beyond primary. M3: spinal/leptomeningeal metastasis. "
            "M4: metastasis outside the CNS. NONE_OF_THE_ABOVE: M-stage not documented."
        ),
    )


class AgeAtDiagnosisMention(SpanAugmentedMention):
    """Patient's age at initial diagnosis in completed months. Extract only if explicitly
    stated. Preserve all ages; age at definitive surgery is a separate trial criterion."""
    age_at_diagnosis_months: int | None = Field(
        default=None, ge=0, le=1500,
        description="Age at initial diagnosis in completed months (e.g. '2 years' -> 24). Null if not stated.",
    )


class DiagnosisDateMention(SpanAugmentedMention):
    """Date the patient was first diagnosed with this embryonal tumor. If several dates
    appear, use the earliest diagnosis date."""
    diagnosis_date: str | None = Field(
        default=None,
        description="Earliest diagnosis date, ISO YYYY-MM-DD (first-of-period if coarse). Null if not stated.",
    )
    diagnosis_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision supported by the text for diagnosis_date. Null when diagnosis_date is null.",
    )


class DiagnosisDateGoldMention(SpanAugmentedMention):
    """Date of the confirmatory ('gold standard') tissue diagnosis — prefer the surgery /
    biopsy procedure date that produced the diagnostic specimen over a later report date."""
    diagnosis_date_gold: str | None = Field(
        default=None,
        description="Confirmatory tissue-diagnosis date, ISO YYYY-MM-DD. Null if not stated.",
    )
    diagnosis_date_gold_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for diagnosis_date_gold. Null when diagnosis_date_gold is null.",
    )


class PcxDiagnosisAnnotation(BaseModel):
    """Embryonal tumor diagnosis annotations from a single clinical note.

    """
    disease_subtype: DiseaseSubtypeMention
    medulloblastoma_histology: MedulloblastomaHistologyMention
    cns_diagnosis_category: CnsDiagnosisCategoryMention
    integrated_diagnosis: CnsIntegratedDiagnosisMention
    tumor_location: TumorLocationMention
    laterality: LateralityMention
    chang_m_stage: ChangMStageMention
    age_at_diagnosis: AgeAtDiagnosisMention
    diagnosis_date: DiagnosisDateMention
    diagnosis_date_gold: DiagnosisDateGoldMention
