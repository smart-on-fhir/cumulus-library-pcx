"""The evidence/date rules warn instead of raise while STRICT_MENTIONS is off."""
import warnings
import os
import subprocess
import sys
import pytest
from pydantic import ValidationError
from cumulus_library_pcx.llm.models import base
from cumulus_library_pcx.llm.models.diagnosis import DiagnosisDateMention, DiseaseSubtypeMention

BAD_SPANS = dict(has_mention=True, spans=[])
BAD_DATE = dict(has_mention=True, spans=["dx 2020"], diagnosis_date="2020-02-15", diagnosis_date_precision="MONTH")
GARBAGE_DATE = dict(has_mention=True, spans=["dx"], diagnosis_date="spring 2020", diagnosis_date_precision="YEAR")


@pytest.mark.parametrize('setting,expected', [(None, 'False'), ('0', 'False'), ('1', 'True')])
def test_default_is_off_unless_environment_says_otherwise(setting, expected):
    env = os.environ.copy()
    env.pop("CUMULUS_PCX_STRICT_MENTIONS", None)
    if setting is not None:
        env["CUMULUS_PCX_STRICT_MENTIONS"] = setting
    result = subprocess.run(
        [sys.executable, '-c',
         'from cumulus_library_pcx.llm.models.base import STRICT_MENTIONS; print(STRICT_MENTIONS)'],
        env=env, capture_output=True, text=True, check=True,
    )
    assert result.stdout.strip() == expected


@pytest.mark.parametrize('value,precision', [
    ('2020-01-01', None), (None, 'YEAR'), ('2020-02-01', 'YEAR'),
    ('2020-02-30', 'DAY'), ('20200101', 'DAY'),
])
def test_off_mode_preserves_invalid_dates(monkeypatch, value, precision):
    monkeypatch.setattr(base, "STRICT_MENTIONS", False)
    with pytest.warns(base.MentionValidationWarning):
        mention = DiagnosisDateMention(
            has_mention=True, spans=['dx'],
            diagnosis_date=value, diagnosis_date_precision=precision,
        )
    assert mention.diagnosis_date == value
    assert mention.diagnosis_date_precision == precision


def test_off_mode_warns_and_accepts(monkeypatch):
    monkeypatch.setattr(base, "STRICT_MENTIONS", False)
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        mention = DiseaseSubtypeMention(**BAD_SPANS)
        dated = DiagnosisDateMention(**BAD_DATE)
        garbage = DiagnosisDateMention(**GARBAGE_DATE)
    assert mention.has_mention is True and mention.spans == []
    assert dated.diagnosis_date == "2020-02-15"
    assert garbage.diagnosis_date == "spring 2020"
    messages = [str(w.message) for w in caught if issubclass(w.category, base.MentionValidationWarning)]
    assert len(messages) == 3
    assert any("evidence spans" in m for m in messages)
    assert any("first day of the month" in m for m in messages)
    assert any("YYYY-MM-DD" in m for m in messages)


def test_on_mode_raises(monkeypatch):
    monkeypatch.setattr(base, "STRICT_MENTIONS", True)
    for payload in (BAD_SPANS, BAD_DATE, GARBAGE_DATE):
        with pytest.raises(ValidationError):
            (DiseaseSubtypeMention if payload is BAD_SPANS else DiagnosisDateMention)(**payload)
