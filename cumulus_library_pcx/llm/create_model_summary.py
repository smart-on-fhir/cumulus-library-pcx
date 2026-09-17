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
import csv
import enum
import importlib
import re
from pathlib import Path
from types import UnionType
from typing import Any, Union, get_args, get_origin

import pydantic

from cumulus_library_pcx.llm.create_schema import TASK_MODELS

BASE_DIR = Path(__file__).parent
COLUMNS = ["annot", "annot_col", "mention_type", "mention_col", "mention_key", "mention_value"]
SPAN_FIELDS = {"has_mention", "spans"}


def _unwrap(tp: Any) -> Any:
    """Strip Optional and list wrappers so `list[X] | None` yields X."""
    origin = get_origin(tp)
    if origin in (Union, UnionType):
        tp = next(arg for arg in get_args(tp) if arg is not type(None))
        origin = get_origin(tp)
    if origin is list:
        tp = get_args(tp)[0]
    return tp


def _is_model(tp: Any) -> bool:
    return isinstance(tp, type) and issubclass(tp, pydantic.BaseModel)


def _is_enum(tp: Any) -> bool:
    return isinstance(tp, type) and issubclass(tp, enum.Enum)


def _clean(text: str | None) -> str:
    """Collapse the newlines and doubled spaces of a wrapped docstring into one line."""
    return " ".join((text or "").split())


def parse_enum_description(description: str, members: list[str]) -> tuple[str, dict[str, str]]:
    """
    Split "preamble. KEY: clause. KEY / KEY: clause." into the preamble and one clause per member.

    >>> parse_enum_description("Pick one. A: first. B / C: shared.", ["A", "B", "C"])
    ('Pick one.', {'A': 'first.', 'B': 'shared.', 'C': 'shared.'})
    """
    names = "|".join(re.escape(member) for member in sorted(members, key=len, reverse=True))
    marker = re.compile(rf"(?:\d+\.\s*)?\b((?:{names})(?:\s*/\s*(?:{names}))*)\s*:")
    matches = list(marker.finditer(description))

    preamble = description[: matches[0].start()] if matches else description
    clauses = dict.fromkeys(members, "")
    for match, following in zip(matches, matches[1:] + [None]):
        end = following.start() if following else len(description)
        clause = _clean(description[match.end():end])
        for key in re.split(r"\s*/\s*", match.group(1)):
            clauses[key] = clause
    return _clean(preamble), clauses


def enum_clauses(enum_type: type[enum.Enum], description: str | None) -> tuple[str, dict[str, str]]:
    """
    The attribute's preamble and one clause per member: the attribute description's own clause
    where it gives one, else the enum docstring's, else "".
    """
    members = [str(member.value) for member in enum_type]
    _, defaults = parse_enum_description(enum_type.__doc__ or "", members)
    preamble, clauses = parse_enum_description(description or "", members)
    for key in members:
        clauses[key] = clauses[key] or defaults[key]
    return preamble, clauses


def _mention_rows(annot: str, annot_col: str, mention: type[pydantic.BaseModel]) -> list[list[str]]:
    """Rows for one mention bound at annot_col: its docstring, then each attribute and enum member."""
    name = mention.__name__
    rows = [[annot, annot_col, name, "", "", _clean(mention.__doc__)]]
    for col, info in mention.model_fields.items():
        if col in SPAN_FIELDS:
            continue
        inner = _unwrap(info.annotation)
        if _is_enum(inner):
            preamble, clauses = enum_clauses(inner, info.label)
            rows.append([annot, annot_col, name, col, "", preamble])
            for key, clause in clauses.items():
                rows.append([annot, annot_col, name, col, key, clause])
        else:
            rows.append([annot, annot_col, name, col, "", _clean(info.label)])
            if _is_model(inner):
                rows.extend(_mention_rows(annot, f"{annot_col}.{col}", inner))
    return rows


def summarize(annotation: type[pydantic.BaseModel]) -> list[list[str]]:
    """Rows for an annotation: its docstring, then each attribute and the mention bound to it."""
    annot = annotation.__name__
    rows = [[annot, "", "", "", "", _clean(annotation.__doc__)]]
    for col, info in annotation.model_fields.items():
        rows.append([annot, col, "", "", "", _clean(info.label)])
        inner = _unwrap(info.annotation)
        if _is_model(inner):
            rows.extend(_mention_rows(annot, col, inner))
    return rows


def create(annotation: type[pydantic.BaseModel], filename: str, output_dir: Path | None = None) -> Path:
    """Write one task's summary CSV, creating the destination directory."""
    directory = Path(output_dir) if output_dir is not None else BASE_DIR / "summaries"
    directory.mkdir(parents=True, exist_ok=True)
    file_path = directory / filename
    with file_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(COLUMNS)
        writer.writerows(summarize(annotation))
    return file_path


def create_pcx_llm_summaries(output_dir: Path | None = None) -> list[Path]:
    """Generate one summary CSV per PCX task, including document routing."""
    paths = []
    for task, class_name in TASK_MODELS.items():
        module = importlib.import_module(f"cumulus_library_pcx.llm.models.{task}")
        paths.append(create(getattr(module, class_name), f"pcx__{task}.csv", output_dir))
    return paths


if __name__ == "__main__":
    for path in create_pcx_llm_summaries():
        print(path)
