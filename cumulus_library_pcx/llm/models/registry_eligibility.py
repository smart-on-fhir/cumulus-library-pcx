"""ACNS0334 trial-comparability evidence, retained at the existing module path.

The EHR discovery cohort includes all ages. These criteria support a separate trial-like
analysis; they do not assert actual trial enrollment or determine eligibility from one
note. No registry consent or tissue-submission pathway is required for PCX entry.
Source: PMC12833527, Patients and Eligibility and Study Design and Treatment.
"""
from enum import StrEnum
from pydantic import BaseModel, Field, model_validator
from .base import SpanAugmentedMention, DatePrecision


class CriterionStatus(StrEnum):
    MET = "MET"
    NOT_MET = "NOT_MET"
    UNKNOWN = "UNKNOWN"
    CONFLICTING = "CONFLICTING"


class TrialCriterionMention(SpanAugmentedMention):
    @model_validator(mode="after")
    def validate_criterion(self):
        if self.status != CriterionStatus.UNKNOWN and not self.has_mention:
            raise ValueError("A criterion finding requires supporting evidence")
        return self

    status: CriterionStatus = Field(default=CriterionStatus.UNKNOWN, description="MET/NOT_MET only with direct evidence for the parent criterion. Missing information is UNKNOWN, never eligible or ineligible by default.")
    assessment_date: str | None = Field(default=None, description="Date to which criterion evidence applies, ISO date at supported precision; preserve pretreatment versus later findings.")
    assessment_date_precision: DatePrecision | None = Field(default=None, description="Precision for assessment_date; null if absent.")


class TrialEligibilityAnnotation(BaseModel):
    age_under_36_months_at_definitive_surgery: TrialCriterionMention = Field(description="Strictly under 36 months AT DEFINITIVE SURGERY. Age at diagnosis alone does not establish this criterion.")
    newly_diagnosed_embryonal_tumor: TrialCriterionMention = Field(description="Newly diagnosed medulloblastoma or historical sPNET/related embryonal tumor; recurrence alone does not establish newly diagnosed disease.")
    high_risk_disease: TrialCriterionMention = Field(description="Documented high-risk MB evidence: residual disease, metastasis, anaplastic histology, or diagnosis under 8 months; historical sPNET any stage. Retain detailed histology/stage/residual measurements separately for stratum adjudication. Do not invent an area threshold from a resection label.")
    atrt_excluded: TrialCriterionMention = Field(description="MET when diagnosis/pathology explicitly excludes ATRT; NOT_MET when ATRT is confirmed; UNKNOWN when unaddressed. Marker loss alone does not diagnose ATRT.")
    no_prior_chemotherapy: TrialCriterionMention = Field(description="No chemotherapy before initial study-like treatment, with steroids allowed. Subsequent chemotherapy is not evidence of pretreatment ineligibility.")
    no_prior_radiation: TrialCriterionMention = Field(description="No radiation before initial study-like treatment. Later discretionary or salvage radiation does not fail this baseline criterion.")
    adequate_renal_function: TrialCriterionMention = Field(description="Explicit baseline renal adequacy or inadequacy. Do not infer adequacy from absent lab results; capture numeric evidence in laboratory.py.")
    adequate_hepatic_function: TrialCriterionMention = Field(description="Explicit baseline hepatic adequacy or inadequacy; retain dated laboratory evidence.")
    adequate_cardiac_function: TrialCriterionMention = Field(description="Explicit baseline cardiac adequacy or inadequacy; preserve supporting assessment.")
    adequate_pulmonary_function: TrialCriterionMention = Field(description="Explicit baseline pulmonary adequacy or inadequacy; preserve supporting assessment.")
    adequate_marrow_function: TrialCriterionMention = Field(description="Explicit baseline marrow adequacy or inadequacy; retain dated counts and transfusion context.")
