"""The variable stage delegates mechanics while keeping build order explicit."""
from pathlib import Path
import tomllib

from cumulus_library_pcx.stage import study_variable
from cumulus_library_pcx.tools import filetool, variable_tool


def test_variable_stage_generates_upload_and_cohorts(monkeypatch):
    # Capture actual generated content, without changing checked-in artifacts.
    outputs = {}

    def capture(text, path):
        outputs[Path(path).name] = text
        return Path(path)

    monkeypatch.setattr(filetool, 'write_text', capture)
    result = study_variable.make()
    manifest = tomllib.loads(outputs[result.name])
    upload, cohorts = manifest['actions']
    assert upload['files'] == ['../spreadsheet/file_upload_study_variable.toml']
    assert cohorts['type'] == 'build:serial'
    names = variable_tool.list_tables_cohort()
    assert names
    assert [Path(path).stem for path in cohorts['files']] == names
    for name in names:
        assert f'CREATE TABLE {name} AS' in outputs[f'{name}.sql']
    assert tomllib.loads(outputs[study_variable.UPLOAD_TOML])['tables']
    assert study_variable.make_actions is study_variable.make_actions


def test_explicit_variable_files_work_without_checkout_discovery(monkeypatch):
    def unexpected_discovery():
        raise AssertionError('Explicit files must not discover checkout inputs')

    monkeypatch.setattr(filetool, 'list_spreadsheet', unexpected_discovery)
    files = [Path('dx_example.csv'), Path('rx_example.csv')]
    assert variable_tool.list_aspect_names(files) == ['dx', 'rx']
    assert variable_tool.list_variables(files, aspect='rx') == ['rx_example']
    assert variable_tool.list_tables(iter(files)) == (
        variable_tool.list_tables_valueset(files) + variable_tool.list_tables_cohort(files)
    )
