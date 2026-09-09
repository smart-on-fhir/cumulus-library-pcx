"""Regression checks for scientific distinctions required by PCX extraction."""
import importlib
import inspect
from pathlib import Path
import pytest
from pydantic import BaseModel, ValidationError
from cumulus_library_pcx.llm.models.base import SpanAugmentedMention
from cumulus_library_pcx.llm.models.medulloblastoma import TreatmentEvidence, SurvivalEvidence
from cumulus_library_pcx.llm.models.molecular import MolecularReportMention, MolecularAlterationMention
from cumulus_library_pcx.llm.models.registry_eligibility import PcxTrialEligibilityAnnotation
from cumulus_library_pcx.llm.models.systemic_therapy import TherapyAdministrationMention, TherapyAgentMention
from cumulus_library_pcx.llm.models.patient import EventFreeFollowUpMention, TimelineAnchorMention
from cumulus_library_pcx.llm.models.response import ResponseAssessmentMention
from cumulus_library_pcx.llm.models.metastasis import MetastaticStagingInputsMention

EMPTY = dict(has_mention=False, spans=[])
EVIDENCE = dict(has_mention=True, spans=['Documented finding'])


def test_all_model_schemas_generate():
    root = Path(__file__).parents[1] / 'cumulus_library_pcx/llm/models'
    for path in root.glob('*.py'):
        module = importlib.import_module('cumulus_library_pcx.llm.models.' + path.stem)
        for _, cls in inspect.getmembers(module, inspect.isclass):
            if issubclass(cls, BaseModel) and cls.__module__ == module.__name__:
                assert cls.model_json_schema()['type'] == 'object'


@pytest.mark.parametrize('payload', [dict(has_mention=True, spans=[]), dict(has_mention=False, spans=['finding']), dict(has_mention=True, spans=[' '])])
def test_evidence_spans_required(payload):
    with pytest.raises(ValidationError):
        SpanAugmentedMention(**payload)


def test_unknown_is_not_absent_or_received():
    assert TreatmentEvidence(**EMPTY).status == 'NOT_DOCUMENTED'
    assert SurvivalEvidence(**EMPTY).patient_deceased is None
    assert TherapyAdministrationMention(**EMPTY).high_dose_methotrexate_explicit_bool is None
    assert TherapyAgentMention(**EMPTY).delivery_status == 'NOT_DOCUMENTED'
    assert MolecularAlterationMention(**EMPTY, target='MYC').status == 'NOT_DOCUMENTED'
    assert MetastaticStagingInputsMention(**EMPTY).csf_cytology == 'UNAVAILABLE'


def test_planned_mtx_does_not_establish_receipt():
    planned = TherapyAdministrationMention(**EVIDENCE, delivery_status='PLANNED', dose_amount=8, dose_unit='g/m2', high_dose_methotrexate_explicit_bool=True)
    assert planned.delivery_status != 'ADMINISTERED'
    assert planned.administration_date is None
    with pytest.raises(ValidationError):
        TreatmentEvidence(**EVIDENCE, status='EXPLICITLY_NOT_RECEIVED', first_received_date='2020-01-01')


def test_molecular_calls_preserve_conflicts_and_distinct_alterations():
    assert MolecularReportMention(**EVIDENCE, molecular_group='CONFLICTING').molecular_group == 'CONFLICTING'
    myc = MolecularAlterationMention(**EVIDENCE, target='MYC', alteration='gain', status='PRESENT')
    mycn = MolecularAlterationMention(**EVIDENCE, target='MYCN', alteration='amplification', status='ABSENT')
    assert myc.target != mycn.target and myc.alteration != mycn.alteration


def test_trial_criteria_default_unknown_and_have_no_registry_pathway():
    result = PcxTrialEligibilityAnnotation(**{name: EMPTY for name in PcxTrialEligibilityAnnotation.model_fields})
    assert all(v.status == 'UNKNOWN' for v in result.__dict__.values())
    assert 'atrt_diagnosis' not in type(result).model_fields
    assert 'consent' not in type(result).model_fields


def test_missing_response_and_alive_are_not_event_free():
    assert ResponseAssessmentMention(**EMPTY).response == 'NOT_DOCUMENTED'
    assert ResponseAssessmentMention(**EMPTY).radiologically_evaluable is None
    assert SurvivalEvidence(**EVIDENCE, patient_deceased=False).patient_deceased is False
    assert EventFreeFollowUpMention(**EMPTY).event_free is None


@pytest.mark.parametrize('day,precision', [('2020-02-30','DAY'), ('2020-01-02','MONTH'), ('2020-02-01','YEAR'), ('2020-01-01',None), (None,'DAY')])
def test_invalid_or_unpaired_dates_rejected(day, precision):
    with pytest.raises(ValidationError):
        TimelineAnchorMention(**EVIDENCE, anchor='DEFINITIVE_SURGERY', anchor_date=day, anchor_date_precision=precision)


def test_partial_date_and_undated_death_preserved():
    anchor = TimelineAnchorMention(**EVIDENCE, anchor='ORIGINAL_DIAGNOSIS', anchor_date='2020-02-01', anchor_date_precision='MONTH')
    assert anchor.anchor_date_precision == 'MONTH'
    assert SurvivalEvidence(**EVIDENCE, patient_deceased=True).death_date is None


def test_unsupported_eligibility_and_false_administration_rejected():
    from cumulus_library_pcx.llm.models.registry_eligibility import TrialCriterionMention
    with pytest.raises(ValidationError):
        TrialCriterionMention(**EMPTY, status='MET')
    with pytest.raises(ValidationError):
        TherapyAdministrationMention(**EVIDENCE, delivery_status='PLANNED', administration_date='2020-01-01', administration_date_precision='DAY')


def test_vital_timeline_contradictions_rejected():
    from cumulus_library_pcx.llm.models.patient import VitalStatusMention
    with pytest.raises(ValidationError):
        VitalStatusMention(**EVIDENCE, vital_status='ALIVE', death_date='2020-01-01', death_date_precision='DAY')
    with pytest.raises(ValidationError):
        VitalStatusMention(**EVIDENCE, vital_status='DECEASED', death_date='2020-01-01', death_date_precision='DAY', last_known_alive_date='2020-01-02', last_known_alive_date_precision='DAY')
