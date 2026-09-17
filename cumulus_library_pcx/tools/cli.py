"""
pcx-study: make Cumulus Library stage manifests for this study.

    pcx-study                 make every stage, then manifest.toml
    pcx-study casedef cube    make only the named stage(s)
    pcx-study --build         make, then `cumulus-library build ... --stage all --force-upload`
    pcx-study cube --build    make cube, then `cumulus-library build ... --stage cube --force-upload`
    pcx-study --list          show stage names
"""
import sys
from argparse import (
    ArgumentParser,
    RawDescriptionHelpFormatter
)
from cumulus_library_pcx.stage.makefile import STAGES
from cumulus_library_pcx.tools import study_builder

def get_parser(stages:list[str]) -> ArgumentParser:
    parser = ArgumentParser(
        prog='pcx-study',
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

def main(argv: list[str] | None = None) -> int:
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
