from pathlib import Path
import os
import sys
import pytest
from cumulus_study_builder.config import set_study_root
from cumulus_study_builder.tools.study_builder import make_study
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
set_study_root(ROOT)
# Local tests never discover real search exports.
os.environ.pop('ELASTIC_OUTPUT_DIR', None)

@pytest.fixture(scope='session', autouse=True)
def generated_study():
    set_study_root(ROOT)
    make_study()
    return ROOT

from study.llm.models import base
@pytest.fixture(autouse=True)
def strict_mentions(monkeypatch):
    monkeypatch.setattr(base, "STRICT_MENTIONS", True)
