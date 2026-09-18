"""Regression checks for scientific distinctions required by PCX extraction."""
import importlib
import inspect
import pytest
from pydantic import BaseModel, ValidationError
from cumulus_library_pcx.llm.models.base import SpanAugmentedMention
from cumulus_library_pcx.tools import filetool
from cumulus_library_pcx.llm.models.molecular import MolecularReportMention, MolecularAlterationMention
from cumulus_library_pcx.llm.models.registry_eligibility import TrialEligibilityAnnotation
from cumulus_library_pcx.llm.models.systemic_therapy import TherapyAdministrationMention, TherapyAgentMention
from cumulus_library_pcx.llm.models.survival_timeline import EventFreeFollowUpMention, TimelineAnchorMention, VitalStatusMention
from cumulus_library_pcx.llm.models.response import ResponseAssessmentMention
from cumulus_library_pcx.llm.models.metastasis import MetastaticStagingInputsMention
from cumulus_library_pcx.stage.llm_schema import make_schemas, list_tasks

EMPTY = dict(has_mention=False, spans=[])
EVIDENCE = dict(has_mention=True, spans=['Documented finding'])


def test_all_model_schemas_generate():
    root = filetool.path_llm('models')
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
    assert VitalStatusMention(**EMPTY).vital_status == 'NONE_OF_THE_ABOVE'
    assert TherapyAdministrationMention(**EMPTY).high_dose_methotrexate_explicit_bool is None
    assert TherapyAgentMention(**EMPTY).delivery_status == 'NONE_OF_THE_ABOVE'
    assert TherapyAgentMention(**EMPTY).assessed_through_date is None
    assert MolecularAlterationMention(**EMPTY, target='MYC').status == 'NONE_OF_THE_ABOVE'
    assert MetastaticStagingInputsMention(**EMPTY).csf_cytology == 'NONE_OF_THE_ABOVE'


def test_planned_mtx_does_not_establish_receipt():
    planned = TherapyAdministrationMention(**EVIDENCE, delivery_status='PLANNED', dose_amount=8, dose_unit='g/m2', high_dose_methotrexate_explicit_bool=True)
    assert planned.delivery_status != 'ADMINISTERED'
    assert planned.administration_date is None
    with pytest.raises(ValidationError):
        TherapyAdministrationMention(**EVIDENCE, delivery_status='EXPLICITLY_NOT_RECEIVED', administration_date='2020-01-01', administration_date_precision='DAY')


def test_molecular_calls_preserve_conflicts_and_distinct_alterations():
    # conflicting calls are kept as separate reports, not collapsed into one value
    reports = [MolecularReportMention(**EVIDENCE, molecular_group=g) for g in ('GROUP_3', 'GROUP_4')]
    assert {r.molecular_group for r in reports} == {'GROUP_3', 'GROUP_4'}
    myc = MolecularAlterationMention(**EVIDENCE, target='MYC', alteration='gain', status='PRESENT')
    mycn = MolecularAlterationMention(**EVIDENCE, target='MYCN', alteration='amplification', status='ABSENT')
    assert myc.target != mycn.target and myc.alteration != mycn.alteration


def test_trial_criteria_default_unknown_and_have_no_registry_pathway():
    result = TrialEligibilityAnnotation(**{name: EMPTY for name in TrialEligibilityAnnotation.model_fields})
    assert all(v.status == 'NONE_OF_THE_ABOVE' for v in result.__dict__.values())
    assert 'atrt_diagnosis' not in type(result).model_fields
    assert 'consent' not in type(result).model_fields


def test_missing_response_and_alive_are_not_event_free():
    assert ResponseAssessmentMention(**EMPTY).response == 'NONE_OF_THE_ABOVE'
    assert ResponseAssessmentMention(**EMPTY).radiologically_evaluable is None
    assert VitalStatusMention(**EVIDENCE, vital_status='ALIVE').vital_status == 'ALIVE'
    assert EventFreeFollowUpMention(**EMPTY).event_free is None


@pytest.mark.parametrize('day,precision', [('2020-02-30','DAY'), ('20200101','DAY'), ('2020-01-02','MONTH'), ('2020-02-01','YEAR'), ('2020-01-01',None), (None,'DAY')])
def test_invalid_or_unpaired_dates_rejected(day, precision):
    with pytest.raises(ValidationError):
        TimelineAnchorMention(**EVIDENCE, anchor='DEFINITIVE_SURGERY', anchor_date=day, anchor_date_precision=precision)


def test_partial_date_and_undated_death_preserved():
    anchor = TimelineAnchorMention(**EVIDENCE, anchor='ORIGINAL_DIAGNOSIS', anchor_date='2020-02-01', anchor_date_precision='MONTH')
    assert anchor.anchor_date_precision == 'MONTH'
    assert VitalStatusMention(**EVIDENCE, vital_status='DECEASED').death_date is None


def test_unsupported_eligibility_and_false_administration_rejected():
    from cumulus_library_pcx.llm.models.registry_eligibility import TrialCriterionMention
    with pytest.raises(ValidationError):
        TrialCriterionMention(**EMPTY, status='MET')
    with pytest.raises(ValidationError):
        TherapyAdministrationMention(**EVIDENCE, delivery_status='PLANNED', administration_date='2020-01-01', administration_date_precision='DAY')


def test_vital_timeline_contradictions_rejected():
    from cumulus_library_pcx.llm.models.survival_timeline import VitalStatusMention
    with pytest.raises(ValidationError):
        VitalStatusMention(**EVIDENCE, vital_status='ALIVE', death_date='2020-01-01', death_date_precision='DAY')
    with pytest.raises(ValidationError):
        VitalStatusMention(**EVIDENCE, vital_status='DECEASED', death_date='2020-01-01', death_date_precision='DAY', last_known_alive_date='2020-01-02', last_known_alive_date_precision='DAY')


def test_schema_generation_writes_one_schema_per_task(tmp_path):
    paths = make_schemas(tmp_path / 'schemas')
    assert len(paths) == len(list_tasks())
    assert all(path.exists() for path in paths)
