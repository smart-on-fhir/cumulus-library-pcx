"""PCX document classification: one document type per note, chosen so that the type
selects which extraction tasks should read the note.

Each DocumentType is defined by WHO produced the document and WHAT it is for, not by
what it mentions. That is what keeps the types mutually exclusive: a neuro-oncology
progress note that quotes the pathology and the last MRI is still an ONCOLOGY_NOTE, the
pathology report is still a PATHOLOGY_REPORT, and the MRI read is still an IMAGING_REPORT.
The precedence list in the description settles the few cases where two definitions
could both apply (a discharge summary written by oncology, a death note written by
neurosurgery). DOCUMENT_TASKS maps each type to the extraction modules that read it.
"""

from enum import StrEnum

from pydantic import BaseModel, Field

from cumulus_library_pcx.llm.models.base import SpanAugmentedMention


class DocumentType(StrEnum):
    """Primary purpose and producing service of a clinical document. Mutually exclusive."""

    OPERATIVE_NOTE = "OPERATIVE_NOTE"
    PATHOLOGY_REPORT = "PATHOLOGY_REPORT"
    IMAGING_REPORT = "IMAGING_REPORT"
    GENETICS_DOCUMENT = "GENETICS_DOCUMENT"
    TREATMENT_ADMINISTRATION_RECORD = "TREATMENT_ADMINISTRATION_RECORD"
    RADIATION_ONCOLOGY_NOTE = "RADIATION_ONCOLOGY_NOTE"
    TUMOR_BOARD_NOTE = "TUMOR_BOARD_NOTE"
    RESEARCH_PROTOCOL_DOCUMENT = "RESEARCH_PROTOCOL_DOCUMENT"
    TRANSFER_DOCUMENT = "TRANSFER_DOCUMENT"
    DISCHARGE_SUMMARY = "DISCHARGE_SUMMARY"
    END_OF_LIFE_DOCUMENT = "END_OF_LIFE_DOCUMENT"
    NEUROSURGERY_NOTE = "NEUROSURGERY_NOTE"
    ONCOLOGY_NOTE = "ONCOLOGY_NOTE"
    OTHER_CLINICAL_NOTE = "OTHER_CLINICAL_NOTE"
    OTHER = "OTHER"


# Which extraction modules (llm/models/<task>.py) read each document type. Selection SQL
# builds pcx__llm_document_task_<task> from this mapping. A task absent from a type's list
# is not run on that type, so a note that mentions a topic outside its type's tasks is
# deliberately not extracted for it (a clinic note's recap of the pathology is not the
# pathology).
DOCUMENT_TASKS: dict[DocumentType, list[str]] = {
    DocumentType.OPERATIVE_NOTE: ["surgery", "diagnosis"],
    DocumentType.PATHOLOGY_REPORT: ["diagnosis", "molecular", "metastasis"],
    DocumentType.IMAGING_REPORT: ["metastasis", "response", "event"],
    DocumentType.GENETICS_DOCUMENT: ["predisposition", "molecular"],
    DocumentType.TREATMENT_ADMINISTRATION_RECORD: ["systemic_therapy"],
    DocumentType.RADIATION_ONCOLOGY_NOTE: ["radiation", "response", "event"],
    DocumentType.TUMOR_BOARD_NOTE: ["diagnosis", "molecular", "metastasis", "response", "registry_eligibility"],
    DocumentType.RESEARCH_PROTOCOL_DOCUMENT: ["registry_eligibility", "systemic_therapy", "patient"],
    DocumentType.TRANSFER_DOCUMENT: ["transition_of_care", "diagnosis", "surgery", "systemic_therapy", "radiation"],
    DocumentType.DISCHARGE_SUMMARY: ["systemic_therapy", "surgery", "event", "patient", "laboratory", "transition_of_care"],
    DocumentType.END_OF_LIFE_DOCUMENT: ["event", "patient"],
    DocumentType.NEUROSURGERY_NOTE: ["surgery", "diagnosis", "event", "transition_of_care"],
    DocumentType.ONCOLOGY_NOTE: ["systemic_therapy", "radiation", "response", "event", "patient", "laboratory",
                                 "registry_eligibility", "medulloblastoma", "transition_of_care"],
    DocumentType.OTHER_CLINICAL_NOTE: ["patient", "event"],
    DocumentType.OTHER: [],
}


DOCUMENT_TYPE_DESCRIPTION = """
Assign exactly one document type from the producing service and the document's primary
purpose. Use the title, author or service, headings, and body together. Classify the
document as a whole: a quoted pathology result, MRI impression, or operative history inside
a clinic note does not change the type of the note that quotes it. Types are defined so
that at most one applies. When two definitions could both fit, the EARLIER entry in this
list wins.

1. END_OF_LIFE_DOCUMENT: the document records the patient's death or the transition to
   comfort-focused care: death note or death summary, pronouncement, autopsy consent or
   report, hospice enrollment or referral, palliative care consult whose purpose is
   end-of-life planning, DNR/DNI or goals-of-care documentation. Wins over every other type
   regardless of authoring service.

2. RESEARCH_PROTOCOL_DOCUMENT: the document exists because of a clinical trial or registry:
   research consent, eligibility checklist, enrollment or randomization confirmation,
   on-study or off-study note, protocol deviation, study coordinator note, protocol
   treatment roadmap. Named-protocol treatment inside an ordinary oncology note is NOT this
   type.

3. TRANSFER_DOCUMENT: the document moves care between institutions or carries another
   institution's information: inter-facility transfer or acceptance note, referral letter
   from or to an outside provider, outside-records summary or review, transport team record,
   a scanned or transcribed outside document (outside operative note, outside pathology,
   outside imaging). A discharge summary written here for a patient going elsewhere is a
   DISCHARGE_SUMMARY, not this.

4. DISCHARGE_SUMMARY: a synopsis of a completed admission written at discharge: reason for
   admission, hospital course, procedures and treatment given, condition and disposition,
   follow-up. Includes chemotherapy-admission discharge summaries authored by oncology.
   Excludes ED discharge notes and nursing discharge instructions (OTHER_CLINICAL_NOTE).

5. OPERATIVE_NOTE: the surgeon's report of an operation: operative report, brief operative
   note, procedure note for a tumor resection, biopsy, shunt, EVD, or second-look surgery.
   Pre-operative and post-operative visit notes are NEUROSURGERY_NOTE, not this.

6. PATHOLOGY_REPORT: a pathologist-signed interpretation of tissue or fluid: surgical
   pathology with final diagnosis, gross and microscopic description, immunohistochemistry,
   FISH, and any molecular or methylation addendum attached to the same accession, CSF or
   other cytology, autopsy neuropathology, and outside-slide consultation reports signed by
   a pathologist. A clinician's note discussing the pathology is not this.

7. IMAGING_REPORT: a radiologist's read of a study: MRI brain or spine, CT, PET, ultrasound,
   with technique, findings, and impression. Includes staging and surveillance studies. A
   neuro-oncology note summarizing the MRI is not this.

8. GENETICS_DOCUMENT: the document is about the patient's germline or inherited risk:
   clinical genetics or genetic counseling note, germline test result or panel report,
   cancer predisposition assessment, family pedigree. Tumor-only molecular results attached
   to a pathology accession are PATHOLOGY_REPORT, not this.

9. TREATMENT_ADMINISTRATION_RECORD: a structured record of what was given rather than a
   narrative note: medication administration record, chemotherapy infusion or treatment
   flowsheet, chemotherapy order set or treatment plan/roadmap with doses and cycle days,
   pharmacy verification, stem-cell infusion record. If it has a narrative assessment and
   plan, it is a note, not this.

10. TUMOR_BOARD_NOTE: a multidisciplinary tumor board or neuro-oncology conference
    summary: case presentation, integrated review of pathology, molecular, imaging and
    staging, and the consensus recommendation.

11. RADIATION_ONCOLOGY_NOTE: any note authored by radiation oncology: consultation,
    simulation or planning note, on-treatment visit, end-of-treatment or completion
    summary, radiation follow-up. Includes notes recommending against or deferring
    radiation.

12. NEUROSURGERY_NOTE: any non-operative note authored by neurosurgery: consultation,
    admission H&P, pre-operative and post-operative visits, inpatient progress, clinic
    follow-up, shunt or hydrocephalus management.

13. ONCOLOGY_NOTE: any note authored by oncology, neuro-oncology, or hematology/oncology
    that is not one of the types above: new-patient consultation, admission H&P for
    chemotherapy, daily inpatient progress note, clinic visit, treatment planning note,
    interval history, off-therapy or survivorship visit, telephone or nurse-practitioner
    oncology note. This is the default for the treating team's own documentation.

14. OTHER_CLINICAL_NOTE: a clinical encounter note from any other service or setting:
    emergency department, PICU or critical care, general pediatrics or hospitalist,
    rehabilitation, physical or occupational or speech therapy, nutrition, endocrinology,
    ophthalmology, neurology, nursing, social work, psychology, anesthesia, ED discharge
    note, nursing discharge instructions.

15. OTHER: not a clinical document, or unclassifiable: administrative or billing note,
    consent unrelated to research, patient education, immunization record, medication
    list without administration data, telephone encounter with no clinical content,
    fax cover, records request, empty or unreadable document.
"""


class DocumentTypeMention(SpanAugmentedMention):
    """Classify one clinical document before task routing.

    Set ``has_mention`` to true when the title, headings, author or service, or body
    provides classification evidence, and put the shortest verbatim title, header, or
    signature cue in ``spans``. Set ``has_mention`` to false, use ``OTHER``, and return an
    empty span list only when the document is empty, unreadable, or too ambiguous to
    classify.

    Document type is a routing feature, not a clinical finding. It says which extraction
    tasks should read the note (DOCUMENT_TASKS), not what the note concludes.
    """

    document_type: DocumentType = Field(
        default=DocumentType.OTHER,
        description=DOCUMENT_TYPE_DESCRIPTION,
    )
    confidence: float | None = Field(
        default=None,
        ge=0.0,
        le=1.0,
        description=(
            "Confidence in the document-type classification from 0.0 to 1.0. Use lower "
            "values when title, authoring service, and body point to different types."
        ),
    )


class DocumentTypeAnnotation(BaseModel):
    """PCX document-type classification for one clinical document."""

    document_type: DocumentTypeMention
