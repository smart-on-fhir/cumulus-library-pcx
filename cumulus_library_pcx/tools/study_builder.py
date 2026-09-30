import shutil
import subprocess
from pathlib import Path
from cumulus_library_pcx.tools import filetool, tablespace, toml_tool
from cumulus_library_pcx.tools.actions import Stage

#-----------------------------------------------------------------------------
# Stages
#-----------------------------------------------------------------------------
def list_stages(stage_list: list[Stage], makeable: bool | None = None) -> list[str]:
    """
    :param makeable: True for Python stages with a make(), False for hand-written
                     on-disk stages, None for every stage
    :return: stage names, in build order
    """
    if makeable is None:
        return [stage.name for stage in stage_list]
    return [stage.name for stage in stage_list if bool(stage.module) == makeable]

def select_stages(stage_list: list[Stage], names: list[str] | None = None) -> list[Stage]:
    """
    :param names: stage names, or None for every stage
    :return: the matching stages, in build order (not the order of `names`)
    """
    if not names:
        return list(stage_list)
    unknown = set(names) - set(list_stages(stage_list))
    if unknown:
        raise KeyError(f"unknown stage(s) {sorted(unknown)}, expected one of {list_stages(stage_list)}")
    return [stage for stage in stage_list if stage.name in names]

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make_stages(stage_list: list[Stage], names: list[str] | None = None) -> list[Path]:
    """
    Run make() for the selected Python stages, in build order.
    :return: list of TOML outputs
    """
    return [stage.module.make() for stage in select_stages(stage_list, names) if stage.module]

def make_manifest(stage_list: list[Stage]) -> Path:
    """
    Write manifest.toml listing every stage, in build order.
    """
    return toml_tool.save_manifest_toml(stage_list)

def make_study(stage_list: list[Stage]) -> list[Path]:
    """
    Make every Python stage, then manifest.toml.
    :return: list of TOML outputs, manifest.toml last
    """
    return make_stages(stage_list) + [make_manifest(stage_list)]

#-----------------------------------------------------------------------------
# Build (cumulus-library)
#-----------------------------------------------------------------------------
def build_command(stage: str = 'all') -> list[str]:
    """
    :param stage: manifest stage name, or 'all'
    :return: argv for `cumulus-library build` of this study
    """
    return ['cumulus-library', 'build',
            '-s', str(filetool.path_project()),
            '-t', tablespace.PREFIX,
            '--stage', stage]

def build(stage: str = 'all') -> None:
    """
    Run `cumulus-library build` for this study; raises if the build fails.
    """
    if shutil.which('cumulus-library') is None:
        raise FileNotFoundError("cumulus-library is not on PATH (is the study venv active?)")
    argv = build_command(stage)
    print(' '.join(argv))
    subprocess.run(argv, check=True)
