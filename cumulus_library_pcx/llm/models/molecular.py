"""Molecular classification and prognostic evidence for ACNS0334 reproduction.

Source: https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/ (Molecular Analyses).
Retain each report independently, including discordant or revised classifications.
Do not infer Group 3 from MYC, histology, age, or treatment. Unknown is not negative.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .base import SpanAugmentedMention, DatePrecision


class MbMolecularGroup(StrEnum):
    WNT = "WNT"
    SHH = "SHH"
    GROUP_3 = "GROUP_3"
    GROUP_4 = "GROUP_4"
    NON_WNT_NON_SHH = "NON_WNT_NON_SHH"
    NOT_SUBGROUPED = "NOT_SUBGROUPED"
    INDETERMINATE = "INDETERMINATE"
    CONFLICTING = "CONFLICTING"
    NONE_OF_THE_ABOVE = "NONE_OF_THE_ABOVE"


class MolecularMethod(StrEnum):
    DNA_METHYLATION = "DNA_METHYLATION"
    SEQUENCING = "SEQUENCING"
    IMMUNOHISTOCHEMISTRY = "IMMUNOHISTOCHEMISTRY"
    FISH = "FISH"
    COPY_NUMBER_ANALYSIS = "COPY_NUMBER_ANALYSIS"
    CLINICAL_SUMMARY = "CLINICAL_SUMMARY"
    OTHER = "OTHER"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"


class MolecularReportMention(SpanAugmentedMention):
    molecular_group: MbMolecularGroup = Field(default=MbMolecularGroup.NONE_OF_THE_ABOVE, description="Explicit medulloblastoma group. NON_WNT_NON_SHH does not distinguish Group 3 from 4. Preserve conflicting calls; never infer a group from a single alteration.")
    integrated_diagnosis_verbatim: str | None = Field(default=None, description="Exact diagnosis/classification, including ETMR, pineoblastoma or revised non-embryonal diagnoses. ATRT can be an exclusion/reclassification finding.")
    methylation_class: str | None = Field(default=None, description="Exact methylation class/subclass, including SHH-I/II or Group 3 subtype if reported.")
    calibrated_score: float | None = Field(default=None, ge=0, le=1, description="Explicit classifier score on a 0–1 scale; do not invent a confidence threshold.")
    methods: list[MolecularMethod] = Field(default_factory=list, description="Methods documented for this result. A note quoting a group without the original method is CLINICAL_SUMMARY.")
    report_date: str | None = Field(default=None, description="Date of this molecular report, ISO date at supported precision; distinct from original diagnosis.")
    report_date_precision: DatePrecision | None = Field(default=None, description="Precision for report_date; null if absent.")
    source_report: str | None = Field(default=None, description="Report identifier, laboratory or referenced report title as documented; do not invent identifiers.")
    specimen: str | None = Field(default=None, description="Tumor, blood or other specimen as documented.")
    review_context: str | None = Field(default=None, description="Local, central, retrospective or revised review, only if documented.")
    uncertainty: str | None = Field(default=None, description="Explicit uncertainty, insufficient tissue, failed testing or conflicting classifications. Null if not stated.")


class AlterationStatus(StrEnum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    INDETERMINATE = "INDETERMINATE"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"


class MolecularAlterationMention(SpanAugmentedMention):
    target: str = Field(description="Exact gene/chromosome, e.g. MYC, MYCN, TP53, isochromosome 17q, chromosome 8, 10 or 11. Keep MYC and MYCN separate.")
    alteration: str | None = Field(default=None, description="Amplification, gain, loss, mutation or isochromosome as stated. Amplification and gain are distinct; preserve the reported term.")
    status: AlterationStatus = Field(default=AlterationStatus.NOT_DOCUMENTED, description="ABSENT requires explicitly negative testing; silence is NOT_DOCUMENTED.")
    origin: str | None = Field(default=None, description="Somatic, germline or unknown as documented; never infer germline from tumor-only testing.")
    report_date: str | None = Field(default=None, description="Date of the source result, ISO date at supported precision.")
    report_date_precision: DatePrecision | None = Field(default=None, description="Precision for report_date; null if absent.")
    source_report: str | None = Field(default=None, description="Documented source report identifier or title linking this alteration to its classification.")
    testing_method: MolecularMethod = Field(default=MolecularMethod.NOT_DOCUMENTED, description="Method supporting this alteration, if stated.")


class PcxMolecularAnnotation(BaseModel):
    reports: list[MolecularReportMention] = Field(default_factory=list, description="One entry per report/classification; retain conflicting reports separately.")
    alterations: list[MolecularAlterationMention] = Field(default_factory=list, description="Documented alterations or explicit negative results; empty is not a negative panel.")
