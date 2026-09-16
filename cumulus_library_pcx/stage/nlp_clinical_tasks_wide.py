"""Prepare clinical NLP SQL and its Cumulus manifest without executing queries.

Run with ``python -m cumulus_library_pcx.stage.nlp_clinical_tasks_wide``.
The generated queries require the selected deployments' NLP source tables.
"""

from pathlib import Path
from typing import Iterable

from cumulus_library_pcx.tools import filetool, manifest, template


DEFAULT_DEPLOYMENTS = ("gpt_oss_120b",)


def prepare_resources(
    deployments: Iterable[str] = DEFAULT_DEPLOYMENTS,
    output_dir: Path | None = None,
) -> list[Path]:
    """Render every available clinical projection, then write its SQL manifest.

    Output paths are relative to the output study directory in the manifest.
    All templates are rendered successfully before any output is written.
    Document routing belongs to a separate workflow and is excluded.
    """
    deployments = sorted(set(deployments))
    tasks = manifest.load_toml("nlp_clinical_tasks.workflow")["tables"]
    versions = {}
    for task, config in tasks.items():
        version = config.get("version")
        if type(version) is not int or version < 1:
            raise ValueError(f"Task {task!r} must have a positive integer version")
        versions[task] = version

    template_dir = filetool.path_llm_template()
    resources = {}
    for template_path in sorted(template_dir.glob("pcx__llm_*.sql.jinja")):
        projection = template_path.name.removeprefix("pcx__llm_").removesuffix(".sql.jinja")
        if projection in {"document_type_wide", "document_topic_wide"}:
            continue
        matching_tasks = [task for task in tasks if projection == task or projection.startswith(task + "_")]
        if not matching_tasks:
            raise ValueError(f"No clinical workflow task matches {template_path.name}")
        task = max(matching_tasks, key=len)
        sql = template.load_llm(
            template_path.name,
            table_names=[f"pcx__nlp_{task}_{deployment}" for deployment in deployments],
            task_version=versions[task],
        )
        resources[filetool.path_llm_athena(template_path.name.removesuffix(".jinja"))] = sql.strip() + "\n"
    if not resources:
        raise ValueError("No clinical SQL templates found")

    action = manifest.FileAction(
        file_list=[path.relative_to(filetool.path_project()).as_posix() for path in resources],
        label="Flattened NLP results for PCX Clinical Tasks",
    )
    directory = Path(output_dir) if output_dir is not None else filetool.path_project()
    paths = []
    for resource_path, sql in resources.items():
        path = directory / resource_path.relative_to(filetool.path_project())
        path.parent.mkdir(parents=True, exist_ok=True)
        if output_dir is None:
            path = filetool.save_llm_athena(resource_path.name, sql)
        else:
            filetool.write_text(sql, path)
        paths.append(path)
    manifest_path = (directory / "nlp_clinical_tasks_wide.toml" if output_dir is not None
                     else filetool.path_project("nlp_clinical_tasks_wide.toml"))
    manifest.save_actions_toml(action, manifest_path)
    return paths + [manifest_path]


def make() -> list[Path]:
    """Prepare default resources and return the generated stage manifest."""
    return [prepare_resources()[-1]]


if __name__ == "__main__":
    for path in prepare_resources():
        print(path)
