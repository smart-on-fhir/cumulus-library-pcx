"""Summarize the PCX extraction models as one CSV per task, for expert review of the
criteria the LLM is given.

Each pcx__<task>.csv is a top-down tree with one row per node and the columns

    annot          the top-level annotation class
    annot_col      the annotation attribute, dotted for a mention nested in a mention
                   (regimens.agents)
    mention_type   the mention class bound to that attribute
    mention_col    the mention attribute
    mention_key    an enum member of that attribute
    mention_value  the text of the node: a class docstring, an attribute description or its
                   non-enum preamble, or the clause the description gives an enum member

The deepest filled column says which node a row is, and parent columns repeat on every row
so the file filters and sorts as a flat table too. A mention bound to several attributes
(TrialCriterionMention, eleven times) is expanded under each of them. The has_mention and
spans boilerplate shared by every mention is left out.

Enum members are spelled out as "KEY: clause. KEY: clause." and that is the only structure the
parser assumes: a member name followed by a colon starts a clause, the clause runs until the
next member name, and text before the first member is the preamble. "KIDNEY / LIVER: named
viscus" gives both members the clause, and the "1. KEY:" numbering of a long list is part of
the marker. Clauses come from the attribute description first and from the enum's class
docstring for any member the attribute does not define (see the convention in models/base.py).
A member defined in neither place gets an empty value, so blank enum rows are also an audit of
which criteria the models do not spell out.
"""
from pathlib import Path

import pydantic

from cumulus_library_pcx.llm.create_schemas import annotation_model, list_tasks
from cumulus_library_pcx.tools import filetool, llm_schema_csv
from cumulus_library_pcx.tools.llm_schema_csv import COLUMNS, enum_clauses, parse_enum_description

SPAN_FIELDS = {"has_mention", "spans"}


def summarize(annotation: type[pydantic.BaseModel]) -> list[list[str]]:
    """Summarize a PCX model, omitting shared evidence-span fields."""
    return llm_schema_csv.summarize(annotation, exclude_fields=SPAN_FIELDS)


def create(annotation: type[pydantic.BaseModel], filename: str, output_dir: Path | None = None) -> Path:
    """Write one task's summary CSV, creating the destination directory."""
    directory = Path(output_dir) if output_dir is not None else filetool.path_llm("summaries")
    return llm_schema_csv.save_summary(annotation, directory / filename, exclude_fields=SPAN_FIELDS)


def create_pcx_llm_summaries(output_dir: Path | None = None) -> list[Path]:
    """Generate one summary CSV per PCX task, including document routing."""
    paths = []
    for task in list_tasks():
        paths.append(create(annotation_model(task), f"pcx__{task}.csv", output_dir))
    return paths


if __name__ == "__main__":
    for path in create_pcx_llm_summaries():
        print(path)
