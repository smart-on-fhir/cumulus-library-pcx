from pathlib import Path

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

def make_study() -> list[Path]:
    return [study_population.make(),
            study_variable.make(),
            study_variable_wide.make(),
            casedef.make(),
            sample.make(),
            eligible.make(),
            outcome.make(),
            client_views.make(),
            qa_athena.make(),
            cube.make()
    ]

if __name__ == '__main__':
    for manifest_toml in make_study():
        print(manifest_toml)
