from pathlib import Path
from types import ModuleType

from cumulus_library_pcx.tools import filetool, manifest
from cumulus_library_pcx.tools.manifest import Stage
from cumulus_library_pcx.stage import (
    study_population,
    study_variable,
    study_variable_wide,
    casedef,
    sample,
    eligible,
    outcome,
    client_views,
    qa_athena,
    cube
)

#-----------------------------------------------------------------------------
# Make targets
#-----------------------------------------------------------------------------
def make(target: ModuleType | str, skip: bool = False) -> Stage:
    """
    Stage entry for manifest.toml.

    :param target: a Python stage module, whose make() writes `<module name>.toml` (built by make_study)
                   or the filename of an existing on-disk `<name>.toml` / `<name>.workflow`
                   (NLP stages: listed in manifest.toml, not built here)
    :param skip: write `skip_by_default = true` for this stage
    """
    if isinstance(target, ModuleType):
        name = target.__name__.rsplit('.', 1)[-1]
        return Stage(name, [f'{name}.toml'], target, skip_by_default=skip)
    if isinstance(target, str):
        path = filetool.path_project(target)
        if not path.exists():
            raise FileNotFoundError(f"stage file not found: {path}")
        return Stage(path.stem, [target], submanifest=(path.suffix == '.toml'), skip_by_default=skip)
    raise TypeError(f"make() expects a stage module or a stage filename, got {type(target).__name__}")

#-----------------------------------------------------------------------------
# Stages in build order: this list is the source of truth for manifest.toml
#-----------------------------------------------------------------------------
STAGES = [
    make(study_population),
    make(study_variable),
    make(study_variable_wide),
    make(casedef),
    make(sample),
    make(casedef),
    make(sample),
    make('elastic_query.toml', skip=True),
    make('elastic_output.toml', skip=True),
    make('nlp_doc_type_tasks_50k.workflow', skip=True),
    make('nlp_clinical_tasks_50k.workflow', skip=True),
    make('nlp_clinical_tasks_wide.toml'),
    make(eligible),
    make(outcome),
    make(client_views),
    make(qa_athena),
    make(cube),
]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make_stages() -> list[Path]:
    """
    Run make() for every Python stage, in build order.
    :return: list of TOML outputs
    """
    out = list()
    for stage in STAGES:
        if stage.module is None:
            continue
        out.append(stage.module.make())
    return out

def make_manifest() -> Path:
    """
    Write manifest.toml listing every stage in STAGES order.
    :return: path to manifest.toml
    """
    return manifest.save_manifest_toml(STAGES)

if __name__ == '__main__':
    for manifest_toml in make_stages():
        print(manifest_toml)
    print(make_manifest())
