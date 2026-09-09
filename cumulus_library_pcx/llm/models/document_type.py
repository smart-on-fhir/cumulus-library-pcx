"""Document classification from DocType Annotation Guidelines (draft May 31, 2025).

Source: project-root ``DocType Annotation Guidelines.docx``, including its decision
tree and category-specific inclusion/exclusion tables. The ten existing enum values
are retained for schema compatibility.

Draft reconciliation: category-specific exclusions override the abbreviated legend
and tree. In particular, the Discharge Summary table excludes ED Discharge Note and
outpatient transfer, despite the legend including ED discharge. The Nursing section
explicitly maps nursing discharge instructions to Discharge Summary. These choices
are encoded below so the LLM receives one consistent formulation.
"""

from enum import StrEnum

from pydantic import BaseModel, Field

from cumulus_library_pcx.llm.models.base import SpanAugmentedMention


class DocumentType(StrEnum):
    """Primary purpose of a clinical document."""

    PROCEDURE_NOTE = "PROCEDURE_NOTE"
    SURGICAL_OPERATION_NOTE = "SURGICAL_OPERATION_NOTE"
    PATHOLOGY_REPORT = "PATHOLOGY_REPORT"
    DIAGNOSTIC_IMAGING_STUDY = "DIAGNOSTIC_IMAGING_STUDY"
    HISTORY_AND_PHYSICAL = "HISTORY_AND_PHYSICAL"
    DISCHARGE_SUMMARY = "DISCHARGE_SUMMARY"
    CONSULT_NOTE = "CONSULT_NOTE"
    PROGRESS_NOTE = "PROGRESS_NOTE"
    NURSING_NOTE = "NURSING_NOTE"
    OTHER = "OTHER"


DOCUMENT_TYPE_DESCRIPTION = """
Assign exactly one document type using the document's main purpose, following the
DocType Annotation Guidelines (draft May 31, 2025). Use the title, author/service,
encounter context and body together. A quoted report or a procedure mentioned in a
history does not change the type of the document containing it.

DECISION PATH:
1. For procedure/test reports, distinguish interpretation of a biopsy specimen
   (PATHOLOGY_REPORT), an operation (SURGICAL_OPERATION_NOTE), non-operative
   procedures or invasive/interventional treatment (PROCEDURE_NOTE), and non-invasive
   imaging/diagnostic testing (DIAGNOSTIC_IMAGING_STUDY).
2. For other notes, consider discharge, explicitly titled H&P, nursing, consult/new
   patient, ongoing specialty care, rehabilitation/nutrition/therapy/allied health,
   then Progress/Clinic/Office titles. Apply the detailed definitions below, including
   the nursing exceptions, before falling back to OTHER.
3. Category-specific inclusions and exclusions take precedence over broad title cues.
   Do not classify from the author's specialty or an isolated word alone.

PROCEDURE_NOTE: a report created immediately following a non-operative procedure,
recording indications, events, tolerance and post-procedure diagnosis when applicable.
Surgery is not the primary act. Include interventional cardiology/cardiac
catheterization, interventional radiology, invasive diagnostic procedures such as
bronchoscopy and bone marrow aspiration, GI endoscopy/colonoscopy/sigmoidoscopy and
other invasive '-scopy' procedures, intubation, and osteopathic manipulation.
Exclude surgical operations, pathology interpretation and non-invasive diagnostic
studies. A marrow aspiration procedure report differs from a marrow biopsy pathology
interpretation.

SURGICAL_OPERATION_NOTE: an operative report, operation note or brief operative note
created following surgery, describing the operation, pre/postoperative diagnoses,
procedural course and postoperative condition. Include outpatient, dental, podiatric
and other specialty operations. Exclude diagnostic studies, interventional radiology
and surgical progress notes. Neither 'surgical' in a title nor surgeon authorship is
sufficient: surgical pathology is PATHOLOGY_REPORT; surgical follow-up is PROGRESS_NOTE.

PATHOLOGY_REPORT: a pathologist-authored interpretation of a biopsy/specimen,
including specimen site, final diagnosis and gross/microscopic findings. Include
anatomic/surgical pathology, bone marrow biopsy interpretations and biopsy results.
A title need not contain 'pathology': Gross Description, Specimen Information or
biopsy-result sections can establish the report context. Surgical pathology reports
belong here, not under surgery or procedure. Exclude oncology notes and other
non-pathologist notes merely discussing pathology; 'biopsy' alone does not turn a
procedure note into a pathology interpretation.

DIAGNOSTIC_IMAGING_STUDY: an interpreting clinician's report of non-invasive imaging
or diagnostic testing. Include XR/mammography, CT, MRI, ultrasound, PET, ECG/EKG,
echocardiography, pulmonary function testing, bone density, EEG and EMG. This category
is not limited to radiology authors. Exclude invasive '-scopy' procedures,
interventional radiology, excision biopsy and blood/fluid laboratory reports.

HISTORY_AND_PHYSICAL: a clearly titled History and Physical, H&P or H+P documenting
initial evaluation, admission, pre-admission, pre-surgery or pre-procedure status.
May be authored by a physician, nurse, other provider or medical student. Exclude
progress, daily rounding, follow-up and notes without a clearly labeled H&P title.
History, examination and assessment sections alone are not sufficient.

DISCHARGE_SUMMARY: a synopsis of a completed hospital, outpatient or post-acute care
episode supporting continuity after discharge. It may describe the reason for care,
procedures/treatment, condition, disposition and follow-up. Include physician and
nurse discharge summaries. Per the Nursing section's explicit rule, nursing
discharge instructions also belong here. Per the detailed Discharge Summary exclusion
table, exclude ED Discharge Notes and outpatient transfer notes; assess those against
the remaining categories and use OTHER if none apply. A discharge title alone does
not override these exclusions.

CONSULT_NOTE: a requested specialist opinion/advice, consultation or referral request.
Include face-to-face consultations, telemedicine and second opinions without direct
patient interaction. The decision tree also routes Consult or New Patient titles
here when documenting an initial specialist evaluation. Distinguish clearly titled
H&P and ongoing specialist follow-up, which belongs to PROGRESS_NOTE. History,
examination and assessment/plan sections can appear in consults and do not make them H&P.

PROGRESS_NOTE: an encounter-associated record of clinical status, illness or treatment
progress during hospitalization or an outpatient visit. Include specialist ongoing
care/follow-up, daily rounding, rehabilitation, nutrition, therapy, allied health,
surgical progress and nursing progress. Progress/Clinic/Office titles support this
classification when the purpose is an encounter update. Examples include ED progress,
home care progress, pharmacy, social work and case-manager progress notes. A standalone
administrative case-management document belongs to OTHER.

NURSING_NOTE: a nursing-titled general note, admission note or nursing assessment and
plan that meets no more specific category. Use as a last resort for nursing documents,
not merely because a nurse is the author. Nursing progress is PROGRESS_NOTE; nursing
H&P is HISTORY_AND_PHYSICAL; nursing discharge summaries and nursing discharge
instructions are DISCHARGE_SUMMARY.

OTHER: no formal category fits after checking the alternatives. Include standalone
immunization documents, death certificates, medication summaries, external/send-out
laboratory reports (e.g. LabCorp/Quest), administrative/billing notes, generic patient
instructions/education, telephone encounters, refill requests, standalone external
documents, administrative case-management notes, HIPAA consent/authorization, fax
cover sheets, claims, authorization letters and record requests. Apply the explicit
nursing-discharge-instructions exception above. Do not label a recognizable clinical
report OTHER simply because it originated externally. Use OTHER for empty/unreadable
or insufficiently identifiable documents as well.
"""


class DocumentTypeMention(SpanAugmentedMention):
    """Classify one clinical document before downstream extraction.

    Set ``has_mention`` to true when the title, headings, authoring context, or body
    provides document-specific classification evidence. Put the shortest verbatim
    title or section cues in ``spans``. Set ``has_mention`` to false, use ``OTHER``,
    and return an empty span list only when the document is empty, unreadable, or too
    ambiguous to classify more specifically.

    Document type is a routing feature, not a clinical phenotype. Study-specific
    extraction priority belongs in selector SQL rather than in this model.
    """

    document_type: DocumentType = Field(
        default=DocumentType.OTHER,
        description=DOCUMENT_TYPE_DESCRIPTION,
    )
    confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description=(
            "Confidence in the document-type classification from 0.0 to 1.0. "
            "Use lower values when the title, authoring context, and body conflict "
            "or provide weak evidence."
        ),
    )


class DocumentTypeAnnotation(BaseModel):
    """Study-neutral document-type classification for one clinical document."""

    document_type: DocumentTypeMention
