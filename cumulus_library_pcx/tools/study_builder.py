from pathlib import Path
from cumulus_library_pcx.tools import manifest
from cumulus_library_pcx.tools.staging import Stage

#-----------------------------------------------------------------------------
# Make
#-----------------------------------------------------------------------------
def make_stages(stage_list:list[Stage]) -> list[Path]:
    return [stage.module.make() for stage in stage_list if stage.module]

def make_manifest(stage_list:list[Stage]) -> Path:
    return manifest.save_manifest_toml(stage_list)
