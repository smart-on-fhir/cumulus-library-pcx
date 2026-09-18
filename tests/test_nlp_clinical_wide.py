"""prepare_resources() writes what its TOML lists, and writes nothing when the deployments are bad.
The rendered SQL itself is checked in test_nlp_wide_contract.py."""
import tomllib
import pytest

from cumulus_library_pcx.stage.nlp_clinical_wide import make_resources


def test_prepare_writes_the_files_its_toml_lists(tmp_path):
    paths = make_resources(output_dir=tmp_path)
    files = tomllib.loads(paths[-1].read_text())["actions"][0]["files"]
    assert set(paths[:-1]) == {tmp_path / file for file in files}
    assert all(path.exists() for path in paths)


def test_bad_deployment_suffix_writes_nothing(tmp_path):
    # the suffix becomes part of an Athena table name: letters, digits and underscores only
    with pytest.raises(ValueError, match="deployment suffixes"):
        make_resources(["bad-suffix"], output_dir=tmp_path)
    with pytest.raises(ValueError, match="deployment suffixes"):
        make_resources([], output_dir=tmp_path)
    assert not list(tmp_path.iterdir())
