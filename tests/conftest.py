"""Test-suite settings: enforce the evidence/date rules so the tests can assert on them."""
import pytest
from cumulus_library_pcx.llm.models import base


@pytest.fixture(autouse=True)
def strict_mentions(monkeypatch):
    """The pipeline default is warn-only; the tests exercise the raising behaviour."""
    monkeypatch.setattr(base, "STRICT_MENTIONS", True)
