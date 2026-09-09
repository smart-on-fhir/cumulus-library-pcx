"""PCX staging evidence from brain/spine MRI, CSF cytology and extraneural assessment.
Record explicit negative findings as well as positives. Missing or indeterminate tests
are not negative. No arbitrary 14-day diagnosis window is applied here. Preserve CSF
collection site/date so downstream rules can assess timing relative to definitive surgery.
An explicitly documented Chang M-stage is captured in diagnosis.py; do not derive one here."""
from enum import StrEnum
from pydantic import BaseModel, Field

from cumulus_library_pcx.llm.models.base import SpanAugmentedMention, DatePrecision


class MetastasisEvidence(StrEnum):
    """Result of a single Chang-staging input assessment."""
    POSITIVE = "POSITIVE"
    NEGATIVE = "NEGATIVE"
    INDETERMINATE = "INDETERMINATE"
    UNAVAILABLE = "UNAVAILABLE"


class MetastaticSite(StrEnum):
    """Anatomic site of metastatic dissemination."""
    CSF = "CSF"
    SPINE = "SPINE"
    BRAIN = "BRAIN"
    LEPTOMENINGEAL = "LEPTOMENINGEAL"
    BONE_MARROW = "BONE_MARROW"
    KIDNEY = "KIDNEY"
    LIVER = "LIVER"
    OTHER = "OTHER"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class MetastaticStagingInputsMention(SpanAugmentedMention):
    """Staging assessments documented together; preserve dates for temporal review."""
    csf_collection_site: str | None = Field(default=None, description="Lumbar, ventricular, or other site exactly as documented; null if unknown.")
    csf_collection_date: str | None = Field(default=None, description="CSF specimen collection date, not result-signoff date; ISO date at supported precision.")
    csf_collection_date_precision: DatePrecision | None = Field(default=None, description="Precision of csf_collection_date; null when absent.")
    brain_mri_date: str | None = Field(default=None, description="Brain metastatic assessment date, ISO date at supported precision.")
    brain_mri_date_precision: DatePrecision | None = Field(default=None, description="Precision of brain_mri_date; null when absent.")
    spine_mri_date: str | None = Field(default=None, description="Spine metastatic assessment date, ISO date at supported precision.")
    spine_mri_date_precision: DatePrecision | None = Field(default=None, description="Precision of spine_mri_date; null when absent.")
    spine_mri_findings: MetastasisEvidence = Field(
        default=MetastasisEvidence.UNAVAILABLE,
        description=(
            "Spine MRI for drop metastases / spinal leptomeningeal seeding. "
            "POSITIVE: seeding present. NEGATIVE: spine MRI done, no seeding. "
            "UNAVAILABLE: spine MRI not done or not reported."
        ),
    )
    brain_mri_findings: MetastasisEvidence = Field(
        default=MetastasisEvidence.UNAVAILABLE,
        description=(
            "Brain MRI for intracranial metastasis/seeding beyond the primary. "
            "POSITIVE: intracranial seeding present. NEGATIVE: done, none. "
            "UNAVAILABLE: not done or not reported."
        ),
    )
    csf_cytology: MetastasisEvidence = Field(
        default=MetastasisEvidence.UNAVAILABLE,
        description=(
            "CSF cytology; record lumbar versus ventricular source and collection date separately. "
            "POSITIVE: malignant cells present. NEGATIVE: cytology negative. "
            "UNAVAILABLE: not performed or not reported."
        ),
    )
    extraneural_metastasis: MetastasisEvidence = Field(
        default=MetastasisEvidence.UNAVAILABLE,
        description=(
            "Metastasis outside the CNS (bone marrow, bone, viscera). "
            "POSITIVE: extraneural metastasis present. NEGATIVE: worked up, none. "
            "UNAVAILABLE: no extraneural workup or not reported."
        ),
    )


class MetastasisSiteMention(SpanAugmentedMention):
    """A single documented metastatic site (applies when there is metastasis, i.e. Chang
    M2/M3/M4). Emit one per distinct site."""
    site: MetastaticSite = Field(
        default=MetastaticSite.NONE_OF_THE_ABOVE,
        description=(
            "CSF: positive CSF/cytology. SPINE: spinal drop metastases. BRAIN: intracranial "
            "metastasis beyond primary. LEPTOMENINGEAL: leptomeningeal spread. "
            "BONE_MARROW: marrow involvement. KIDNEY / LIVER: named viscus. OTHER: another site. "
            "NONE_OF_THE_ABOVE: no metastatic site documented."
        ),
    )
    site_date: str | None = Field(
        default=None,
        description="Date this metastatic site was documented, ISO YYYY-MM-DD. Null if not stated.",
    )
    site_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for site_date. Null when site_date is null.",
    )


class PcxMetastasisAnnotation(BaseModel):
    """Metastasis / Chang-staging annotations from a single clinical note.

    """
    staging_inputs: MetastaticStagingInputsMention
    metastasis_sites: list[MetastasisSiteMention] = Field(
        default_factory=list,
        description="All documented metastatic sites; empty list if none / localized disease.",
    )
