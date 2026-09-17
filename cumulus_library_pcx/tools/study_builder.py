from pathlib import Path
from types import ModuleType

from cumulus_library_pcx.tools import manifest
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
# Helpers
#-----------------------------------------------------------------------------
def make(target: ModuleType | str, skip_by_default: bool | None = None) -> Stage:
    """
    Stage entry for manifest.toml.

    :param target: a Python stage module, whose make() writes `<module name>.toml`
                   (built by make_study, not skipped by default)
                   or the str name of a hand-written `<name>.workflow` (NLP tasks)
                   (listed only, skipped by default)
    :param skip_by_default: override the default for that kind of target
    """
    if isinstance(target, ModuleType):
        name = target.__name__.rsplit('.', 1)[-1]
        return Stage(name, [f'{name}.toml'], target,
                     skip_by_default=False if skip_by_default is None else skip_by_default)
    if isinstance(target, str):
        return Stage(target, [f'{target}.workflow'], submanifest=False,
                     skip_by_default=True if skip_by_default is None else skip_by_default)
    raise TypeError(f"make() expects a stage module or a workflow name, got {type(target).__name__}")

#-----------------------------------------------------------------------------
# Stages in build order: this list is the source of truth for manifest.toml
#-----------------------------------------------------------------------------
STAGES = [
    make(study_population),
    make(study_variable),
    make(study_variable_wide),
    make(casedef),
    make(sample),
    make('nlp_doc_type_tasks_50k'),
    make('nlp_clinical_tasks_50k'),
    Stage('nlp_clinical_tasks_wide', ['nlp_clinical_tasks_wide.toml']),
    make(eligible),
    make(outcome),
    make(client_views),
    make(qa_athena),
    make(cube),
]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make_study() -> list[Path]:
    """
    Run make() for every Python stage, in build order.
    :return: list of TOML outputs
    """
    out = list()
    for stage in STAGES:
        if stage.module is None:
            continue
        made = stage.module.make()
        out.extend(made if isinstance(made, list) else [made])
    return out

def make_manifest() -> Path:
    """
    Write manifest.toml listing every stage in STAGES order.
    :return: path to manifest.toml
    """
    return manifest.save_manifest_toml(STAGES)

if __name__ == '__main__':
    for manifest_toml in make_study():
        print(manifest_toml)
    print(make_manifest())
