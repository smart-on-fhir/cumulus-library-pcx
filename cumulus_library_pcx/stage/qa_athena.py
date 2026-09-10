from pathlib import Path
from cumulus_library_pcx.tools import filetool, manifest, template, tablespace

## ----------------------------------------------------------------------------
## helpers

def list_templates() -> list[Path]:
    return sorted(list(filetool.path_tests_template().glob("*.sql")))

def list_athena(wildcard:str, exclude:str='') -> list[Path]:
    table_glob = tablespace.name_prefix(wildcard)
    file_list = list(filetool.path_tests_athena().glob(table_glob))
    return sorted([f for f in file_list if exclude not in str(f)])

def list_qa() -> list[Path]:
    return list_athena('qa_*.sql', tablespace.name_prefix('qa_union.sql'))

def list_warn() -> list[Path]:
    return list_athena('warn_*.sql', tablespace.name_prefix('warn_union.sql'))

def list_example() -> list[Path]:
    """Return user-facing examples built only from client tables."""
    return list_athena('example_*.sql', '')

def list_tables(file_list:list[Path]) -> list[str]:
    return [file.stem for file in file_list]

def _make_union(table_part, file_list:list[Path]) -> Path:
    table = tablespace.name_prefix(table_part)
    ctas = f'CREATE TABLE {table} AS '
    text = [f"SELECT COUNT(*) as cnt, '{table}' as test \n FROM {table}"
            for table in list_tables(file_list)]
    text = ctas + '\n' + '\n UNION ALL \n'.join(text)
    return filetool.write_text(text, filetool.path_tests_athena(f"{table}.sql"))

## ----------------------------------------------------------------------------
## make

def make_union() -> list[Path]:
    return [_make_union('qa_union', list_qa()),
            _make_union('warn_union', list_warn()),
            _make_union('example_union', list_example())]

def relative_to_athena(path_list:list[Path])->list[str]:
    return [f'../tests/athena/{file.name}' for file in path_list]

def make() -> list[Path]:
    for t in list_templates():
        template.copy_test(t)

    actions = [
        manifest.FileAction(
            relative_to_athena(list_qa()),
            description="all *qa* tables should have zero rows",
            build_type='build:parallel'),
        manifest.FileAction(
            relative_to_athena(list_warn()),
            description="warn tables - nonzero rows are findings to eyeball, not failures",
            build_type='build:parallel'),
        manifest.FileAction(
            relative_to_athena(list_example()),
            description="example tables for client users",
            build_type='build:parallel'),
        manifest.FileAction(
            relative_to_athena(make_union()),
            description="union qa",
            build_type='build:parallel')
    ]
    return [manifest.save_actions_toml(actions, 'qa_athena.toml')]

if __name__ == '__main__':
    print(make())