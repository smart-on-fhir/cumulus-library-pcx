from pathlib import Path
from types import ModuleType
from dataclasses import dataclass

#-----------------------------------------------------------------------------
# Stage
#-----------------------------------------------------------------------------
@dataclass(frozen=True)
class Stage:
    """
    One `[[stages.<name>]]` entry of the top-level manifest.toml.

    target is either
    * a Python stage module: its make() writes `<module name>.toml` (built by the makefile), or
    * the filename of an existing on-disk `<name>.toml` / `<name>.workflow`
      (NLP and elastic stages: listed in manifest.toml, not built)

    `manifest.py` owns the TOML details:
    * Stage.name becomes the `[[stages.<name>]]` table
    * Stage.files becomes the TOML `files` key
    * Stage.submanifest writes `type = "submanifest"` (Cumulus Library reads `.workflow` files without a type)
    * Stage.skip_by_default is written only when true
    """
    target: ModuleType | str
    skip_by_default: bool = False

    @property
    def module(self) -> ModuleType | None:
        """Python stage to build, or None for an on-disk file that is only listed."""
        return self.target if isinstance(self.target, ModuleType) else None

    @property
    def name(self) -> str:
        if self.module:
            return self.module.__name__.rsplit('.', 1)[-1]
        return Path(self.target).stem

    @property
    def files(self) -> list[str]:
        return [f'{self.name}.toml'] if self.module else [self.target]

    @property
    def submanifest(self) -> bool:
        return bool(self.module) or self.target.endswith('.toml')

#-----------------------------------------------------------------------------
# Actions
#-----------------------------------------------------------------------------
@dataclass(frozen=True)
class Action:
    """
    Cumulus Library basic build action type.

    `manifest.py` owns the TOML details:
    * Action.label becomes the TOML `label` key
    """
    file_list: list[Path] | list[str]
    label: str = ""

@dataclass(frozen=True)
class FileAction(Action):
    build_type: str = "build:parallel"

@dataclass(frozen=True)
class SqlAction(Action):
    build_type: str = "build:serial"

@dataclass(frozen=True)
class SqlParallelAction(SqlAction):
    build_type: str = "build:parallel"

@dataclass(frozen=True)
class ExportAction(Action):
    export_type: str = "export:counts"

#-----------------------------------------------------------------------------
# Workflows
#-----------------------------------------------------------------------------
@dataclass(frozen=True)
class UploadWorkflow:
    """
    Cumulus Library `file_upload` workflow (CSV uploads): a TOML with `config_type = "file_upload"`,
    reached from a build action whose `files` lists it. Not an `[[actions]]` entry.

    `manifest.py` owns the TOML details:
    * UploadWorkflow.file_list becomes one `[tables.<table_name>]` block per file
    * table_name is `<prefix><simplename>` when prefix is given
    * otherwise `include_*` files keep their simplename, all others get `valueset_<simplename>`
    * no label: Cumulus Library rejects unknown keys in file_upload TOML
    """
    file_list: list[Path] | list[str]
    prefix: str | None = None
