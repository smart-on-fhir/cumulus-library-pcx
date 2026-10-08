"""Build the data-only PyPI release of PCX: rendered SQL and data files, no Python code.

Run from any directory, with the study's development venv active: the script finds the
repository through the builder's filetool, so cumulus-study-builder must be installed in the
Python that runs it. It also needs SSH read access to the builder repository.

    python release/make_data_release.py

Steps, each stopping at the first problem:
  1. venv      build/release/venv with the builder tag and the tested pins (requirements-tested.txt)
  2. render    `cumulus-study build` and `cumulus-study validate` in this checkout, without an
               Elasticsearch export: the released pcx__elastic_union is the empty table.
               Run `cumulus-study build` afterwards to render your own export again.
  3. assemble  build/release/package/: the released stages, the rendered SQL and workflows they
               list, and the spreadsheet files they upload. `../spreadsheet/` paths become
               `spreadsheet/` inside the package.
  4. check     only the released stages, no Python file but __init__.py, no path leaving the
               package, no SQL that reads LLM or NLP tables
  5. build     wheel and sdist into build/release/dist/, then `twine check`

It never uploads and never runs git: it prints the upload command for you to run.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tomllib
import zipfile
from pathlib import Path

from cumulus_study_builder.config import set_study_root
from cumulus_study_builder.tools import filetool

# Select this checkout by its cumulus-study.toml, whatever the working directory is.
set_study_root(filetool.path_root(__file__))
ROOT = filetool.path_root()
STUDY = filetool.path_project()
PACKAGE_NAME = 'cumulus_library_pcx'
DIST_NAME = 'cumulus-library-pcx'
BUILDER = 'git+ssh://git@github.com/smart-on-fhir/cumulus-study-builder.git@v0.5.3'

# The default stages (PROTOCOL.md decision log, 2026-10-02 and 2026-10-08), in manifest order.
RELEASED_STAGES = ['study_population', 'study_variable', 'study_variable_wide', 'casedef',
                   'elastic_upload', 'sample', 'counts', 'study_meta']
# Where a site keeps its Elasticsearch export. The release is rendered without one.
EXPORT_VARIABLES = ['ELASTIC_OUTPUT_DIR', 'CUMULUS_LIBRARY_DATA_PATH']
FILE_SUFFIXES = ('.sql', '.toml', '.workflow')


class ReleaseError(Exception):
    pass


def run(command: list, cwd: Path = ROOT, env: dict | None = None) -> str:
    print('$', ' '.join(str(part) for part in command), flush=True)
    result = subprocess.run([str(part) for part in command], cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        print(result.stdout)
        raise ReleaseError(f'command failed ({result.returncode}): {command[0]}')
    return result.stdout


# --------------------------------------------------------------------------- 1. venv

def make_venv(out: Path, builder: str) -> Path:
    venv = out / 'venv'
    run([sys.executable, '-m', 'venv', venv])
    python = venv / 'bin' / 'python'
    run([python, '-m', 'pip', 'install', '--quiet', '--upgrade', 'pip'])
    run([python, '-m', 'pip', 'install', '--quiet', '-c', ROOT / 'requirements-tested.txt',
         builder, 'build', 'twine'])
    return venv


def installed_version(venv: Path, dist: str) -> str:
    code = f'import importlib.metadata as m; print(m.version({dist!r}))'
    return run([venv / 'bin' / 'python', '-c', code]).strip()


# --------------------------------------------------------------------------- 2. render

def render(venv: Path) -> None:
    env = dict(os.environ)
    for name in EXPORT_VARIABLES:
        env.pop(name, None)
    run([venv / 'bin' / 'cumulus-study', 'build'], env=env)
    run([venv / 'bin' / 'cumulus-study', 'validate'], env=env)


# --------------------------------------------------------------------------- 3. assemble

def packaged_path(relative: str) -> str:
    """Path of a study-relative file inside the release package."""
    if relative.startswith('../spreadsheet/'):
        return relative.removeprefix('../')
    if relative.startswith('../') or relative.startswith('/'):
        raise ReleaseError(f'{relative}: only ../spreadsheet/ may point outside the study package')
    return relative


def rewrite_paths(text: str) -> str:
    return text.replace('"../spreadsheet/', '"spreadsheet/')


def copy_file(source: Path, target: Path, text_rewrite: bool = False) -> None:
    if source.is_symlink():
        raise ReleaseError(f'{source}: symlinks are not released')
    if not source.is_file():
        raise ReleaseError(f'{source}: referenced but missing')
    if not source.resolve().is_relative_to(ROOT):
        raise ReleaseError(f'{source}: outside the repository')
    target.parent.mkdir(parents=True, exist_ok=True)
    if text_rewrite:
        target.write_text(rewrite_paths(source.read_text(encoding='utf-8')), encoding='utf-8')
    else:
        shutil.copyfile(source, target)


def manifest_blocks(text: str) -> tuple[str, dict[str, list[str]]]:
    """The header and the [[stages.<name>]] blocks of a rendered manifest.toml, by stage name."""
    parts = re.split(r'(?m)^(?=\[\[stages\.)', text)
    blocks = dict()
    for part in parts[1:]:
        name = re.match(r'\[\[stages\.([A-Za-z0-9_]+)\]\]', part).group(1)
        blocks.setdefault(name, list()).append(part.rstrip('\n') + '\n')
    return parts[0], blocks


def write_manifest(package: Path) -> list[str]:
    """Released manifest.toml. Returns the stage TOMLs it lists."""
    text = (STUDY / 'manifest.toml').read_text(encoding='utf-8')
    stages = tomllib.loads(text)['stages']
    header, blocks = manifest_blocks(text)

    missing = [name for name in RELEASED_STAGES if name not in stages]
    if missing:
        raise ReleaseError(f'manifest.toml lacks released stages: {missing}')

    released_blocks = list()
    stage_files = list()
    for name in stages:
        if name not in RELEASED_STAGES:
            continue
        for entry in stages[name]:
            if entry.get('type') != 'submanifest' or entry.get('skip_by_default'):
                raise ReleaseError(f'stage {name}: expected a default submanifest, got {entry}')
            stage_files.extend(entry['files'])
        released_blocks.extend(blocks[name])

    out = rewrite_paths(header.rstrip('\n')) + '\n\n' + '\n'.join(released_blocks)
    (package / 'manifest.toml').write_text(out, encoding='utf-8')
    return stage_files


def copy_upload(source_toml: Path, target_toml: Path) -> None:
    """A file_upload TOML and the data files it uploads, which sit beside it."""
    copy_file(source_toml, target_toml)
    upload = tomllib.loads(source_toml.read_text(encoding='utf-8'))
    if upload.get('config_type') != 'file_upload':
        raise ReleaseError(f'{source_toml}: not a file_upload config')
    for table, config in upload['tables'].items():
        files = config['files'] if 'files' in config else [config['file']]
        for name in files:
            copy_file(source_toml.parent / name, target_toml.parent / name)


def assemble(package: Path) -> None:
    study = package / PACKAGE_NAME
    study.mkdir(parents=True)
    stage_files = write_manifest(study)
    copy_file(filetool.path_spreadsheet('data_dictionary.csv'), study / 'spreadsheet' / 'data_dictionary.csv')

    for stage_file in stage_files:
        copy_file(STUDY / stage_file, study / packaged_path(stage_file), text_rewrite=True)
        stage = tomllib.loads((STUDY / stage_file).read_text(encoding='utf-8'))
        for action in stage['actions']:
            references = action.get('files', []) + action.get('tables', [])
            for reference in references:
                if not reference.endswith(FILE_SUFFIXES):
                    continue    # a table name, such as pcx__meta_date
                source = STUDY / reference
                target = study / packaged_path(reference)
                if reference.endswith('.toml'):
                    copy_upload(source, target)
                elif not target.exists():
                    copy_file(source, target)

    (study / '__init__.py').write_text(
        '"""PCX study for Cumulus Library: rendered SQL and data files, no code."""\n', encoding='utf-8')


def source_commit() -> str:
    """The checkout's commit, read from .git without running git."""
    git = ROOT / '.git'
    head = (git / 'HEAD').read_text().strip()
    if not head.startswith('ref: '):
        return head
    ref = head.removeprefix('ref: ')
    if (git / ref).is_file():
        return (git / ref).read_text().strip()
    packed = git / 'packed-refs'
    if packed.is_file():
        for line in packed.read_text().splitlines():
            if line.endswith(' ' + ref):
                return line.split(' ')[0]
    return 'unknown'


def write_project(package: Path, version: str, library: str, builder: str) -> None:
    (package / 'pyproject.toml').write_text(f'''[build-system]
requires = ["flit_core>=3.9,<4"]
build-backend = "flit_core.buildapi"

[project]
name = "{DIST_NAME}"
version = "{version}"
description = "PCX medulloblastoma study for Cumulus Library: rendered SQL and data files, no Python code."
readme = "README.md"
requires-python = ">=3.11"
dependencies = []

[project.urls]
Source = "https://github.com/smart-on-fhir/cumulus-library-pcx"

[tool.flit.module]
name = "{PACKAGE_NAME}"
''', encoding='utf-8')

    stages = ''.join(f'- `{name}`\n' for name in RELEASED_STAGES)
    (package / 'README.md').write_text(f'''# {DIST_NAME} {version} (data-only)

The PCX study (Cumulus table prefix `pcx`) as rendered SQL and data files, with no Python
code and no dependencies. Rendered from commit `{source_commit()}` of
[smart-on-fhir/cumulus-library-pcx](https://github.com/smart-on-fhir/cumulus-library-pcx) with
cumulus-study-builder {builder} and Cumulus Library {library}.

Stages:

{stages}
The NLP, eligibility, outcome, client-view and QA stages are not in this release.

Install it next to Cumulus Library {library}, which finds the installed `{PACKAGE_NAME}`
package through its study allowlist, then build after the core study:

```sh
pip install {DIST_NAME}=={version}
cumulus-library build -t pcx
```
''', encoding='utf-8')


# --------------------------------------------------------------------------- 4. check

def check(package: Path) -> None:
    study = package / PACKAGE_NAME
    python_files = sorted(str(p.relative_to(study)) for p in study.rglob('*.py'))
    if python_files != ['__init__.py']:
        raise ReleaseError(f'Python files in the package: {python_files}')

    manifest = tomllib.loads((study / 'manifest.toml').read_text(encoding='utf-8'))
    if list(manifest['stages']) != RELEASED_STAGES:
        raise ReleaseError(f'released manifest stages: {list(manifest["stages"])}')
    if manifest['data_dictionary'] != 'spreadsheet/data_dictionary.csv':
        raise ReleaseError(f'data_dictionary = {manifest["data_dictionary"]}')

    prefix = manifest['study_prefix'] + '__'
    problems = list()
    for path in sorted(study.rglob('*')):
        if path.is_dir():
            continue
        text = path.read_text(encoding='utf-8-sig')
        if path.suffix == '.toml' and '"../' in text:
            problems.append(f'{path.relative_to(study)}: path leaves the package')
        if path.suffix in ('.sql', '.workflow') and re.search(rf'\b{prefix}(llm|nlp)_', text):
            problems.append(f'{path.relative_to(study)}: reads an LLM or NLP table')
    if problems:
        raise ReleaseError('\n'.join(problems))


# --------------------------------------------------------------------------- 5. build

def build(venv: Path, package: Path, dist: Path) -> list[Path]:
    run([venv / 'bin' / 'python', '-m', 'build', '--outdir', dist, package])
    built = sorted(dist.iterdir())
    run([venv / 'bin' / 'twine', 'check', '--strict'] + built)

    wheels = [path for path in built if path.suffix == '.whl']
    if len(wheels) != 1:
        raise ReleaseError(f'expected one wheel, got {wheels}')
    names = zipfile.ZipFile(wheels[0]).namelist()
    python_files = [name for name in names if name.endswith('.py')]
    if python_files != [f'{PACKAGE_NAME}/__init__.py']:
        raise ReleaseError(f'Python files in the wheel: {python_files}')
    if f'{PACKAGE_NAME}/manifest.toml' not in names:
        raise ReleaseError('manifest.toml is missing from the wheel')
    return built


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--builder', default=BUILDER, help='pip requirement for cumulus-study-builder')
    parser.add_argument('--out', type=Path, default=ROOT / 'build' / 'release',
                        help='work directory, must not exist yet (default build/release)')
    args = parser.parse_args()

    out = args.out.resolve()
    if out.exists():
        raise ReleaseError(f'{out} exists: remove it first, so nothing stale is released')
    version = tomllib.loads((ROOT / 'pyproject.toml').read_text())['project']['version']

    venv = make_venv(out, args.builder)
    library = installed_version(venv, 'cumulus-library')
    builder = installed_version(venv, 'cumulus-study-builder')
    render(venv)

    package = out / 'package'
    assemble(package)
    write_project(package, version, library, builder)
    check(package)
    built = build(venv, package, out / 'dist')

    count = sum(1 for path in (package / PACKAGE_NAME).rglob('*') if path.is_file())
    print(f'\n{DIST_NAME} {version}: {count} files, stages {", ".join(RELEASED_STAGES)}')
    print(f'cumulus-library {library}, cumulus-study-builder {builder}, commit {source_commit()}')
    for path in built:
        print(f'  {path}')
    print('\nUpload when ready (PyPI keeps a version number forever):')
    print(f'  {venv / "bin" / "twine"} upload {out / "dist"}/*')


if __name__ == '__main__':
    try:
        main()
    except ReleaseError as error:
        sys.exit(f'release stopped: {error}')
