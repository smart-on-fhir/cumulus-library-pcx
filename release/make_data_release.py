"""Build the data-only PyPI release of PCX: rendered SQL and data files, no Python code.

Run from any directory, with the study's development venv active: the script finds the
repository through the builder's filetool, so cumulus-study-builder must be installed in the
Python that runs it. It also needs SSH read access to the builder repository.

    python release/make_data_release.py

Steps, each stopping at the first problem:
  1. venv      build/release/venv with the builder tag and the tested pins (requirements-tested.txt)
  2. study    `cumulus-study build` and `cumulus-study validate` in this checkout, without an
               Elasticsearch export: the released pcx__elastic_union is the empty table.
               Run `cumulus-study build` afterwards to render your own export again.
  3. assemble  build/release/package/: the study's manifest.toml as is, every stage TOML and
               workflow it lists with the rendered SQL and spreadsheet files they name, and every
               LLM response schema in llm/schemas/. `../spreadsheet/` and `../tests/sql/custom/`
               paths move inside the package. Python builders (stage/llm_schema.py) are not
               released, so the opt-in llm_schema stage cannot run from the package.
  4. check     Cumulus Library loads the released manifest, every file a stage lists is in the
               package (Python builders excepted), no Python file but __init__.py, no path
               leaving the package, every LLM schema present and every NLP workflow's schema found
  5. build     wheel and sdist into build/release/dist/, then `twine check`

It never uploads and never runs git: it prints the upload command for you to run.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tomllib
import zipfile
from pathlib import Path

from cumulus_library.study_manifest import StudyManifest
from cumulus_study_builder.config import set_study_root
from cumulus_study_builder.tools import filetool, template

# Select this checkout by its cumulus-study.toml, whatever the working directory is.
set_study_root(filetool.path_root(__file__))
ROOT = filetool.path_root()
STUDY = filetool.path_project()
PACKAGE_NAME = 'cumulus_library_pcx'
DIST_NAME = 'cumulus-library-pcx'
BUILDER = 'git+ssh://git@github.com/smart-on-fhir/cumulus-study-builder.git@v0.5.6'

# Folders outside the study package that stages read from: `../<folder>/` in the study
# becomes `<folder>/` inside the released package.
OUTSIDE_FOLDERS = ['spreadsheet', 'tests/sql/custom']

# Where a site keeps its Elasticsearch export. The release is rendered without one.
EXPORT_VARIABLES = ['ELASTIC_OUTPUT_DIR', 'CUMULUS_LIBRARY_DATA_PATH']
FILE_SUFFIXES = ('.sql', '.toml', '.workflow')

# LLM response schemas: all are released, including those of the unreleased clinical tasks.
SCHEMA_DIR = 'llm/schemas'

# Jinja templates beside this script, rendered into the package root as <name>.
RELEASE_DIR = Path(__file__).resolve().parent
PROJECT_TEMPLATES = ['pyproject.toml']

class ReleaseError(Exception):
    pass

#-----------------------------------------------------------------------------
# 1. virtualenv
#-----------------------------------------------------------------------------
def make_venv(out: Path, builder: str) -> Path:
    venv = out / 'venv'
    run([sys.executable, '-m', 'venv', venv])
    python = venv / 'bin' / 'python'
    run([python, '-m', 'pip', 'install', '--quiet', '--upgrade', 'pip'])
    run([python, '-m', 'pip', 'install', '--quiet', '-c', ROOT / 'requirements-tested.txt',
         builder, 'build', 'twine'])
    return venv


# ---------------------------------------------------------------------------
# 2. build study
# ---------------------------------------------------------------------------
def build_study(venv: Path) -> None:
    env = dict(os.environ)
    for name in EXPORT_VARIABLES:
        env.pop(name, None)
    run([venv / 'bin' / 'cumulus-study', 'build'], env=env)
    run([venv / 'bin' / 'cumulus-study', 'validate'], env=env)


# ---------------------------------------------------------------------------
# 3. Package
# ---------------------------------------------------------------------------
def packaged_path(relative: str) -> str:
    """Path of a study-relative file inside the release package."""
    for folder in OUTSIDE_FOLDERS:
        if relative.startswith(f'../{folder}/'):
            return relative.removeprefix('../')
    if relative.startswith('../') or relative.startswith('/'):
        raise ReleaseError(f'{relative}: only {OUTSIDE_FOLDERS} may be outside the study package')
    return relative


def rewrite_paths(text: str) -> str:
    for folder in OUTSIDE_FOLDERS:
        text = text.replace(f'"../{folder}/', f'"{folder}/')
    return text

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


def manifest_files() -> list[str]:
    """The stage TOMLs and workflows the study manifest lists, in stage order."""
    stages = tomllib.loads((STUDY / 'manifest.toml').read_text(encoding='utf-8'))['stages']
    files = list()
    for entries in stages.values():
        for entry in entries:
            files.extend(entry['files'])
    return files


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
    copy_file(STUDY / 'manifest.toml', study / 'manifest.toml', text_rewrite=True)
    copy_file(filetool.path_spreadsheet('data_dictionary.csv'), study / 'spreadsheet' / 'data_dictionary.csv')

    for stage_file in manifest_files():
        copy_file(STUDY / stage_file, study / packaged_path(stage_file), text_rewrite=True)
        if stage_file.endswith('.workflow'):
            continue    # an NLP workflow: its schemas are copied with all the others below
        stage = tomllib.loads((STUDY / stage_file).read_text(encoding='utf-8'))
        for action in stage['actions']:
            references = action.get('files', []) + action.get('tables', [])
            for reference in references:
                if not reference.endswith(FILE_SUFFIXES):
                    continue    # a table name (pcx__meta_date) or a Python builder (stage/llm_schema.py)
                source = STUDY / reference
                target = study / packaged_path(reference)
                if reference.endswith('.toml'):
                    copy_upload(source, target)
                elif not target.exists():
                    copy_file(source, target)

    for schema in study_schemas():
        copy_file(STUDY / SCHEMA_DIR / schema, study / SCHEMA_DIR / schema)

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


def write_project(package: Path, version: str) -> None:
    """pyproject.toml of the package, from the Jinja template in release/."""
    env = template.environment(RELEASE_DIR)
    values = dict(dist_name=DIST_NAME,
                  package_name=PACKAGE_NAME,
                  version=version)
    for name in PROJECT_TEMPLATES:
        text = env.get_template(name + '.jinja').render(**values)
        (package / name).write_text(text, encoding='utf-8')


# ---------------------------------------------------------------------------
# 4. check
# ---------------------------------------------------------------------------
def check(package: Path) -> None:
    study = package / PACKAGE_NAME
    python_files = sorted(str(p.relative_to(study)) for p in study.rglob('*.py'))
    if python_files != ['__init__.py']:
        raise ReleaseError(f'Python files in the package: {python_files}')

    # Loading opens every stage TOML, every TOML or workflow an action lists and the data
    # dictionary, as a site's `cumulus-library build` does before it runs anything.
    try:
        manifest = StudyManifest(study)
    except Exception as error:
        raise ReleaseError(f'Cumulus Library cannot load the released manifest: {error}')
    missing = set()
    for name in manifest.get_stages():
        for action in manifest.get_stage(name):
            for file in action.get('files', []):
                if not file.endswith('.py') and not (study / file).is_file():
                    missing.add(file)
    if missing:
        raise ReleaseError(f'listed in the released manifest but not in the package: {sorted(missing)}')

    schemas = sorted(path.name for path in (study / SCHEMA_DIR).glob('*.json'))
    if schemas != study_schemas():
        raise ReleaseError(f'released LLM schemas {schemas}, study has {study_schemas()}')

    problems = list()
    for workflow in sorted(study.rglob('*.workflow')):
        config = tomllib.loads(workflow.read_text(encoding='utf-8'))
        if config.get('config_type') != 'nlp':
            continue
        for table, task in config['tables'].items():
            if not (study / task['response_schema']).is_file():
                problems.append(f'{workflow.relative_to(study)}: {table} schema is missing')
    for path in sorted(study.rglob('*')):
        if path.is_dir():
            continue
        text = path.read_text(encoding='utf-8-sig')
        if path.suffix == '.toml' and '"../' in text:
            problems.append(f'{path.relative_to(study)}: path leaves the package')
    if problems:
        raise ReleaseError('\n'.join(problems))

# ---------------------------------------------------------------------------
# 5. build
# ---------------------------------------------------------------------------
def build(venv: Path, package: Path, dist: Path) -> list[Path]:
    run([venv / 'bin' / 'python', '-m', 'build', '--outdir', dist, package])
    built = sorted(dist.iterdir())
    run([venv / 'bin' / 'twine', 'check'] + built)

    wheels = [path for path in built if path.suffix == '.whl']
    if len(wheels) != 1:
        raise ReleaseError(f'expected one wheel, got {wheels}')
    names = zipfile.ZipFile(wheels[0]).namelist()
    python_files = [name for name in names if name.endswith('.py')]
    if python_files != [f'{PACKAGE_NAME}/__init__.py']:
        raise ReleaseError(f'Python files in the wheel: {python_files}')
    if f'{PACKAGE_NAME}/manifest.toml' not in names:
        raise ReleaseError('manifest.toml is missing from the wheel')
    missing = [schema for schema in study_schemas()
               if f'{PACKAGE_NAME}/{SCHEMA_DIR}/{schema}' not in names]
    if missing:
        raise ReleaseError(f'LLM schemas missing from the wheel: {missing}')
    return built

#-----------------------------------------------------------------------------
# Helpers
#-----------------------------------------------------------------------------
def study_schemas() -> list[str]:
    """File names of the study's LLM response schemas, which must exist."""
    schemas = sorted(path.name for path in (STUDY / SCHEMA_DIR).glob('*.json'))
    if not schemas:
        raise ReleaseError(f'no LLM schemas in {STUDY / SCHEMA_DIR}')
    return schemas

def installed_version(venv: Path, dist: str) -> str:
    code = f'import importlib.metadata as m; print(m.version({dist!r}))'
    return run([venv / 'bin' / 'python', '-c', code]).strip()

def run(command: list, cwd: Path = ROOT, env: dict | None = None) -> str:
    print('$', ' '.join(str(part) for part in command), flush=True)
    result = subprocess.run([str(part) for part in command], cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        print(result.stdout)
        raise ReleaseError(f'command failed ({result.returncode}): {command[0]}')
    return result.stdout

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
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
    build_study(venv)

    package = out / 'package'
    assemble(package)
    write_project(package, version)
    check(package)
    built = build(venv, package, out / 'dist')

    count = sum(1 for path in (package / PACKAGE_NAME).rglob('*') if path.is_file())
    stages = tomllib.loads((STUDY / 'manifest.toml').read_text(encoding='utf-8'))['stages']
    print(f'\n{DIST_NAME} {version}: {count} files, stages {", ".join(stages)}')
    print(f'cumulus-library {library}, cumulus-study-builder {builder}, commit {source_commit()}')
    for path in built:
        print(f'  {path}')
    print('\nUpload when ready (PyPI keeps a version number forever):')
    print(f'  {venv / "bin" / "twine"} upload {out / "dist"}/*')



#-----------------------------------------------------------------------------
# Main
#-----------------------------------------------------------------------------
if __name__ == '__main__':
    try:
        main()
    except ReleaseError as error:
        sys.exit(f'release stopped: {error}')
