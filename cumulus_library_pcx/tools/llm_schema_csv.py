"""Export human-readable CSV summaries of Pydantic annotation models.

These review summaries describe fields and enum choices; they are not JSON
validation schemas. Callers supply models, output paths, and fields to omit.
"""
import csv
import enum
import re
from collections.abc import Iterable
from pathlib import Path
from types import UnionType
from typing import Any, Union, get_args, get_origin

import pydantic

COLUMNS = ["annot", "annot_col", "mention_type", "mention_col", "mention_key", "mention_value"]


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


def _mention_rows(annot: str, annot_col: str, mention: type[pydantic.BaseModel],
                  exclude_fields: frozenset[str]) -> list[list[str]]:
    """Rows for one mention bound at annot_col: its docstring, then each attribute and enum member."""
    name = mention.__name__
    rows = [[annot, annot_col, name, "", "", _clean(mention.__doc__)]]
    for col, info in mention.model_fields.items():
        if col in exclude_fields:
            continue
        inner = _unwrap(info.annotation)
        if _is_enum(inner):
            preamble, clauses = enum_clauses(inner, info.description)
            rows.append([annot, annot_col, name, col, "", preamble])
            for key, clause in clauses.items():
                rows.append([annot, annot_col, name, col, key, clause])
        else:
            rows.append([annot, annot_col, name, col, "", _clean(info.description)])
            if _is_model(inner):
                rows.extend(_mention_rows(annot, f"{annot_col}.{col}", inner, exclude_fields))
    return rows


def summarize(annotation: type[pydantic.BaseModel], *,
              exclude_fields: Iterable[str] = ()) -> list[list[str]]:
    """Rows for an annotation: its docstring, then each attribute and the mention bound to it."""
    exclude_fields = frozenset(exclude_fields)
    annot = annotation.__name__
    rows = [[annot, "", "", "", "", _clean(annotation.__doc__)]]
    for col, info in annotation.model_fields.items():
        if col in exclude_fields:
            continue
        rows.append([annot, col, "", "", "", _clean(info.description)])
        inner = _unwrap(info.annotation)
        if _is_model(inner):
            rows.extend(_mention_rows(annot, col, inner, exclude_fields))
    return rows


def save_summary(annotation: type[pydantic.BaseModel], file_path: Path | str, *,
                 exclude_fields: Iterable[str] = ()) -> Path:
    """Write the model's review CSV, creating the output directory."""
    rows = summarize(annotation, exclude_fields=exclude_fields)
    file_path = Path(file_path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    with file_path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.writer(output)
        writer.writerow(COLUMNS)
        writer.writerows(rows)
    return file_path
