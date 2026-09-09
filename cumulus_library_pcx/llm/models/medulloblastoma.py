"""Broad PCX any-dose discovery summary. Use detailed companion models for ACNS0334 reproduction."""
from datetime import date
from enum import StrEnum
from pydantic import BaseModel, Field, model_validator
from cumulus_library_pcx.llm.models.base import SpanAugmentedMention


class EvidenceStatus(StrEnum):
    RECEIVED = 'RECEIVED'
    EXPLICITLY_NOT_RECEIVED = 'EXPLICITLY_NOT_RECEIVED'
    NOT_DOCUMENTED = 'NOT_DOCUMENTED'


class MedulloblastomaGroup(StrEnum):
    WNT = 'WNT'
    SHH = 'SHH'
    GROUP_3 = 'GROUP_3'
    GROUP_4 = 'GROUP_4'
    NON_WNT_NON_SHH = 'NON_WNT_NON_SHH'
    CONFLICTING = 'CONFLICTING'
    OTHER = 'OTHER'
    NONE_OF_THE_ABOVE = 'NONE_OF_THE_ABOVE'


class TreatmentEvidence(SpanAugmentedMention):
    """Patient-specific delivered treatment for medulloblastoma at any dose and route,
    including historical delivery. Exclude treatment for unrelated diseases or tumors. Orders, plans, held doses and discussion alone do not establish receipt.
    An explicit negative applies only through the documented assessment date.
    """
    status: EvidenceStatus = Field(default=EvidenceStatus.NOT_DOCUMENTED, description="RECEIVED: explicitly administered or delivered, any dose, including historical treatment. EXPLICITLY_NOT_RECEIVED: explicit non-receipt through assessment. NOT_DOCUMENTED: silence, plans, hypothetical or uncertain receipt.")
    first_received_date: date | None = Field(default=None, description='Earliest explicitly dated administration. Exact day only; null for partial or missing dates.')
    assessed_through_date: date | None = Field(default=None, description='Date through which receipt or explicit non-receipt is documented. Never infer from the extraction date.')

    @model_validator(mode='after')
    def evidence_contract(self):
        if self.status != EvidenceStatus.NOT_DOCUMENTED and (not self.has_mention or not self.spans):
            raise ValueError('A treatment finding requires a mention and supporting spans')
        if self.status != EvidenceStatus.RECEIVED and self.first_received_date is not None:
            raise ValueError('Only received treatment can have an administration date')
        if self.first_received_date and self.assessed_through_date and self.first_received_date > self.assessed_through_date:
            raise ValueError('Administration cannot follow its assessment date')
        return self


class GroupEvidence(SpanAugmentedMention):
    classification_method: str | None = Field(default=None, description="Documented subgroup method; clinical summary is not automatically methylation confirmation.")
    source_report: str | None = Field(default=None, description="Source molecular report as stated; preserve conflicts in molecular.py reports.")
    group: MedulloblastomaGroup = Field(default=MedulloblastomaGroup.NONE_OF_THE_ABOVE, description="Explicit molecular group: WNT, SHH, GROUP_3, GROUP_4, NON_WNT_NON_SHH, CONFLICTING, OTHER. NONE_OF_THE_ABOVE for absent or indeterminate classification. Do not infer from treatment or histology.")

    @model_validator(mode='after')
    def evidence_contract(self):
        if self.group != MedulloblastomaGroup.NONE_OF_THE_ABOVE and (not self.has_mention or not self.spans):
            raise ValueError('A molecular group requires supporting evidence')
        return self


class SurvivalEvidence(SpanAugmentedMention):
    patient_deceased: bool | None = Field(default=None, description='True only for explicit death, false only for explicit alive status, null when undocumented.')
    death_date: date | None = Field(default=None, description='Actual date of death, exact day only. Never substitute the note date.')
    last_known_alive_date: date | None = Field(default=None, description='Exact day the patient was documented alive. A note mentioning a deceased patient is not alive evidence.')

    @model_validator(mode='after')
    def evidence_contract(self):
        if (self.patient_deceased is not None or self.death_date or self.last_known_alive_date) and (not self.has_mention or not self.spans):
            raise ValueError('Vital findings require supporting evidence')
        if self.death_date and self.patient_deceased is not True:
            raise ValueError('A death date requires explicit deceased status')
        if self.death_date and self.last_known_alive_date and self.last_known_alive_date > self.death_date:
            raise ValueError('Alive evidence cannot follow death')
        return self


class PcxMedulloblastomaAnnotation(BaseModel):
    """One note's evidence for the PCX medulloblastoma comparison. Do not infer
    subgroup from age, treatment or histology. Any-dose flags do not identify the ACNS0334 high-dose induction regimen;
    use systemic_therapy.py for delivered dose, phase and backbone evidence. Preserve verbatim spans for all findings and conflicting evidence
    across notes for downstream review. Diagnosis and age come from structured data.
    """
    molecular_group: GroupEvidence
    methotrexate: TreatmentEvidence
    radiation: TreatmentEvidence
    survival: SurvivalEvidence
