"""Render SQL templates from bare names, `.sql` names, or `.sql.jinja` names."""
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, StrictUndefined
from cumulus_library.template_sql import base_templates
from cumulus_library_pcx.tools import filetool
from cumulus_library_pcx.tools.tablespace import PREFIX

#-----------------------------------------------------------------------------
# Naming
#-----------------------------------------------------------------------------
def name_template(sql_file: Path | str) -> str:
    """
    Normalize a bare name, `<name>.sql`, or `<name>.sql.jinja` to the template filename.
    """
    name = sql_file.name if isinstance(sql_file, Path) else sql_file
    if not name.endswith(('.sql', '.sql.jinja')):
        name = f'{name}.sql'
    return name if name.endswith('.jinja') else f'{name}.jinja'

#-----------------------------------------------------------------------------
# Load
#-----------------------------------------------------------------------------
def load(sql_file: Path | str, **kwargs) -> str:
    """
    sql = load("meta_version.sql", data_package_version="1.0.0")
    sql = load("sample_casedef_temporality.sql", temporality="pre")

    `sql_file` may be a bare name, `<name>.sql`, or `<name>.sql.jinja`.
    """
    return _render(filetool.path_template(), sql_file, **kwargs)

def load_test(sql_file: Path | str, **kwargs) -> str:
    """Render from tests/template/ -- keeps QA/test SQL out of the production template/ folder."""
    return _render(filetool.path_tests_template(), sql_file, **kwargs)

def load_llm(sql_file: Path | str, **kwargs) -> str:
    """Render from llm/template/ with the shared Cumulus SQL macros."""
    return _render(filetool.path_llm_template(), sql_file, **kwargs)

#-----------------------------------------------------------------------------
# Save
#-----------------------------------------------------------------------------
def save(sql_file: Path | str, **kwargs) -> Path:
    """Render template/ -> athena/{PREFIX}__<name>.sql"""
    return _save(filetool.path_template(), filetool.path_athena, sql_file, **kwargs)

def save_list(sql_list: list[Path | str] | Path | str, **kwargs) -> list[Path]:
    """
    Render many templates at once, template/ -> athena/{PREFIX}__<name>.sql

    files = copy_list(["study_population", "study_population_dx"])
    files = copy_list("meta_date.sql")

    Names may be bare table names ("x"), "x.sql", or "x.sql.jinja".
    The same **kwargs are passed to every template.
    """
    if isinstance(sql_list, (Path, str)):
        sql_list = [sql_list]
    out = list()
    for sql_file in sql_list:
        out.append(save(sql_file, **kwargs))
    return out

def save_test(sql_file: Path | str, **kwargs) -> Path:
    """Render tests/template/ -> tests/athena/{PREFIX}__<name>.sql"""
    return _save(filetool.path_tests_template(), filetool.path_tests_athena, sql_file, **kwargs)

#-----------------------------------------------------------------------------
# Helpers
#-----------------------------------------------------------------------------
def _render(template_dir: Path, sql_file: Path | str, **kwargs) -> str:
    """Render a Jinja SQL template found in `template_dir`."""
    kwargs.setdefault("prefix", PREFIX)
    macro_dir = Path(base_templates.__file__).parent / "shared_macros"
    env = Environment(loader=FileSystemLoader([template_dir, macro_dir]),
                      undefined=StrictUndefined)
    env.globals["db_type"] = "athena"
    return env.get_template(name_template(sql_file)).render(**kwargs)

def _save(template_dir: Path, athena_path, sql_file: Path | str, **kwargs) -> Path:
    """Render `sql_file` from `template_dir` and write it under `athena_path` as
    `{PREFIX}__<name>.sql`."""
    file_name = name_template(sql_file).removesuffix('.jinja')
    text = _render(template_dir, file_name, **kwargs)
    return filetool.write_text(text, athena_path(f"{PREFIX}__{file_name}"))
