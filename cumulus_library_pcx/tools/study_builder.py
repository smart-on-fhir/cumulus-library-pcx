from pathlib import Path

from cumulus_library_pcx.tools import (
    study_population,
    study_variable,
    study_variable_wide,
    casedef,
    sample,
    eligible,
    outcome,
)

def make_study() -> list[Path]:
    return (study_population.make() +
            study_variable.make() +
            study_variable_wide.make() +
            casedef.make() +
            sample.make() +
            eligible.make() +
            outcome.make())

if __name__ == '__main__':
    for manifest_toml in make_study():
        print(manifest_toml)
