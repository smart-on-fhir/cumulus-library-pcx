"""
make-pcx: make Cumulus Library stage manifests for this study.

    make-pcx                 make every stage, then manifest.toml
    make-pcx casedef cube    make only the named stage(s)
    make-pcx --build         make, then `cumulus-library build ... --stage all --force-upload`
    make-pcx cube --build    make cube, then `cumulus-library build ... --stage cube --force-upload`
    make-pcx --list          show stage names
    make-pcx test-synthetic  regenerate the synthetic eligible/outcome CSVs in tests/data/synthetic
                             (options after the word are passed on: --patients, --seed, --noise, ...)
"""
import sys
import importlib.util
from pathlib import Path
from argparse import (
    ArgumentParser,
    RawDescriptionHelpFormatter
)
from cumulus_library_pcx.stage.makefile import STAGES
from cumulus_library_pcx.tools import filetool, study_builder

#  Command words handled before stage parsing. They are not stages and never appear in --list.
COMMAND_TEST_SYNTHETIC = 'test-synthetic'

def get_parser(stages:list[str]) -> ArgumentParser:
    parser = ArgumentParser(
        prog='make-pcx',
        description=__doc__,
        formatter_class=RawDescriptionHelpFormatter)

    parser.add_argument('stage',
                        nargs='*',
                        metavar='STAGE',
                        help=f"stage name(s) to make: {', '.join(stages)} (default: all)")

    parser.add_argument('--list',
                        action='store_true',
                        help='list stage names and exit')

    parser.add_argument('--build',
                        action='store_true',
                        help='after make, run `cumulus-library build` for the stage(s) (all when none named)')
    return parser

#-----------------------------------------------------------------------------
# tests/data/synthetic
#-----------------------------------------------------------------------------
def load_tests_synthetic():
    """
    The synthetic-data generator is test code, kept out of the study package on purpose:
    tests/synthetic.py in the repository checkout, which `pip install -e .` from a clone provides.
    """
    path = filetool.path_tests('synthetic.py')
    if not path.exists():
        raise SystemExit(f'make-pcx {COMMAND_TEST_SYNTHETIC} needs the repository checkout: {path} not found '
                         '(clone the repo and `pip install -e ".[test]"`)')
    # console scripts do not put the checkout on sys.path, and another installed package
    # may own the name `tests`: put this checkout first so `tests.tools` is ours
    checkout = str(path.parent.parent)
    if checkout in sys.path:
        sys.path.remove(checkout)
    sys.path.insert(0, checkout)
    imported = sys.modules.get('tests')
    if imported is not None and Path(imported.__file__).parent != path.parent:
        for name in [name for name in sys.modules if name == 'tests' or name.startswith('tests.')]:
            del sys.modules[name]
    spec = importlib.util.spec_from_file_location('tests.synthetic', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

#-----------------------------------------------------------------------------
# Main
#-----------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else list(argv)
    if argv and argv[0] == COMMAND_TEST_SYNTHETIC:
        return load_tests_synthetic().make_tests_synthetic(argv[1:])

    stages = study_builder.list_names(STAGES)
    parser = get_parser(stages)
    args = parser.parse_args(argv)

    if args.list:
        print('\n'.join(stages))
        return 0

    unknown = sorted(set(args.stage) - set(stages))
    if unknown:
        parser.error(f"unknown stage {', '.join(unknown)} (choose from {', '.join(stages)})")

    if args.stage:
        made = study_builder.make_stages(STAGES, args.stage)
    else:
        made = study_builder.make_study(STAGES)

    for path in made:
        print(path)

    if args.build:
        for stage in args.stage or ['all']:
            study_builder.build(stage)
    return 0


if __name__ == '__main__':
    sys.exit(main())
