"""Molecular classification and prognostic evidence for ACNS0334 reproduction.

Source: https://pmc.ncbi.nlm.nih.gov/articles/PMC12833527/ (Molecular Analyses).
Retain each report independently, including discordant or revised classifications.
Do not infer Group 3 from MYC, histology, age, or treatment. Unknown is not negative.
"""
from enum import StrEnum
from pydantic import BaseModel, Field
from .base import SpanAugmentedMention, DatePrecision


class MedulloblastomaMolecularGroup(StrEnum):
    """Medulloblastoma molecular group as reported.
    WNT: WNT.
    SHH: SHH.
    GROUP_3: Group 3.
    GROUP_4: Group 4.
    NON_WNT_NON_SHH: non-WNT/non-SHH.
    NOT_SUBGROUPED: not subgrouped.
    INDETERMINATE: indeterminate.
    CONFLICTING: conflicting group calls.
    NONE_OF_THE_ABOVE: no group documented."""
    WNT = "WNT"
    SHH = "SHH"
    GROUP_3 = "GROUP_3"
    GROUP_4 = "GROUP_4"
    NON_WNT_NON_SHH = "NON_WNT_NON_SHH"
    NOT_SUBGROUPED = "NOT_SUBGROUPED"
    INDETERMINATE = "INDETERMINATE"
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
    molecular_group: MedulloblastomaMolecularGroup = Field(
        default=MedulloblastomaMolecularGroup.NONE_OF_THE_ABOVE,
        description=(
            "Explicit medulloblastoma molecular group as this report states it. "
            "Preserve conflicting calls across reports. Never infer a group from a single alteration, "
            "from histology, or from treatment. "
            "WNT: WNT-activated. "
            "SHH: SHH-activated, any TP53 status. "
            "GROUP_3: Group 3 by methylation or expression profiling. "
            "GROUP_4: Group 4 by methylation or expression profiling. "
            "NON_WNT_NON_SHH: non-WNT/non-SHH without a Group 3 versus Group 4 call, as from immunohistochemistry. "
            "NOT_SUBGROUPED: testing explicitly not performed or not available. "
            "INDETERMINATE: testing attempted but no classification reached, such as failed assay or insufficient tissue. "            
            "NONE_OF_THE_ABOVE: no molecular group documented in this report."
        ),
    )

    methods: list[MolecularMethod] = Field(
        default_factory=list,
        description=(
            "Methods this report documents for molecular classification." 
            "Pick one: "
            "DNA_METHYLATION: methylation array or methylation-based classifier. "
            "SEQUENCING: DNA or RNA sequencing, including expression-based subgrouping such as NanoString. "
            "IMMUNOHISTOCHEMISTRY: surrogate markers such as beta-catenin, GAB1, YAP1 or filamin A. "
            "FISH: fluorescence in situ hybridization. "
            "COPY_NUMBER_ANALYSIS: array or sequencing-derived copy number. "
            "CLINICAL_SUMMARY: the note quotes a group without the original report or method. "
            "OTHER: another named method. "
            "NOT_DOCUMENTED: a result is stated but no method is given."
        ),
    )

    report_date: str | None = Field(
        default=None,
        description="Date of this molecular report, ISO date at supported precision; distinct from original diagnosis."
    )
    report_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for report_date; null if absent."
    )


class AlterationStatus(StrEnum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    INDETERMINATE = "INDETERMINATE"
    NOT_DOCUMENTED = "NOT_DOCUMENTED"


class MolecularAlterationMention(SpanAugmentedMention):
    target: str = Field(
        description="Exact gene/chromosome, e.g. MYC, MYCN, TP53, isochromosome 17q, chromosome 8, 10 or 11. "
                    "Keep MYC and MYCN separate."
    )
    alteration: str | None = Field(
        default=None,
        description="Amplification, gain, loss, mutation or isochromosome as stated. "
                    "Amplification and gain are distinct; preserve the reported term."
    )
    status: AlterationStatus = Field(
        default=AlterationStatus.NOT_DOCUMENTED,
        description="Status of this alteration. "
                    "ABSENT: requires explicitly negative testing. NOT_DOCUMENTED: silence."
    )
    report_date: str | None = Field(
        default=None,
        description="Date of the source result, ISO date at supported precision."
    )
    report_date_precision: DatePrecision | None = Field(
        default=None,
        description="Precision for report_date; null if absent."
    )
    testing_method: MolecularMethod = Field(
        default=MolecularMethod.NOT_DOCUMENTED,
        description="Method supporting this alteration, if stated."
    )

class MolecularAnnotation(BaseModel):
    reports: list[MolecularReportMention] = Field(default_factory=list, description="One entry per report/classification; retain conflicting reports separately.")
    alterations: list[MolecularAlterationMention] = Field(default_factory=list, description="Documented alterations or explicit negative results; empty is not a negative panel.")
