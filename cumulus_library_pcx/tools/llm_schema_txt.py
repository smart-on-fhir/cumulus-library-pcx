"""Export plain-text summaries of Pydantic annotation models.

A summary reads like the model an LLM is asked to fill in: one line per field with
its type, then its description and enum choices as indented comments, recursing into
nested models. For example:

    model = "ExampleAnnotation"
    status = ReviewStatus (Choice Value)
        # Choose one.
        # Possible Values:
        #   - YES
        #   - NO
    mentions: A (possibly empty) list of ReviewMention instances, which contain:
        score = Optional mention of [Integer number between 0 and 3 (inclusive)]

These are review summaries, not validation schemas (see llm_schema_json), and a
sibling of the tabular llm_schema_csv. Callers supply models, output paths and the
fields to omit, typically the has_mention / spans boilerplate every mention shares.
"""
import enum
from collections.abc import Iterable
from pathlib import Path
from types import UnionType
from typing import Any, Union, get_args, get_origin

import pydantic

INDENT = "    "

#-----------------------------------------------------------------------------
# Type inspection
#-----------------------------------------------------------------------------
def _unwrap_optional(tp: Any) -> tuple[Any, bool]:
    """Optional[T] / T | None -> (T, True); anything else -> (tp, False)."""
    if get_origin(tp) in (Union, UnionType):
        args = get_args(tp)
        if len(args) == 2 and type(None) in args:
            other = args[0] if args[1] is type(None) else args[1]
            return other, True
    return tp, False

def _is_model(tp: Any) -> bool:
    return isinstance(tp, type) and issubclass(tp, pydantic.BaseModel)

def _is_enum(tp: Any) -> bool:
    return isinstance(tp, type) and issubclass(tp, enum.Enum)

def _model_type(tp: Any) -> tuple[type[pydantic.BaseModel] | None, bool]:
    """(model, is_list) for Model, list[Model] and their Optional forms, else (None, False)."""
    base, _ = _unwrap_optional(tp)
    if get_origin(base) is list:
        args = get_args(base)
        if args and _is_model(args[0]):
            return args[0], True
    if _is_model(base):
        return base, False
    return None, False

def _enum_type(tp: Any) -> type[enum.Enum] | None:
    """The enum of Enum, list[Enum] and their Optional forms, else None."""
    base, _ = _unwrap_optional(tp)
    if get_origin(base) is list:
        args = get_args(base)
        base = args[0] if args else None
    return base if _is_enum(base) else None

#-----------------------------------------------------------------------------
# Rendering types
#-----------------------------------------------------------------------------
def bounds_to_string(metadata: Iterable[Any]) -> str:
    """
    Numeric bounds as a phrase, or "" when there are none.

    Pydantic keeps Field(ge=..., le=...) in FieldInfo.metadata, not on the annotation:
        ge=0, le=3   -> "between 0 and 3 (inclusive)"
        ge=0         -> "0 or greater"
        gt=0, le=10  -> "greater than 0 and 10 or less"
    Bounds are read off whichever attribute a constraint exposes, which covers separate
    Ge/Le/Gt/Lt objects and a combined Interval alike; MultipleOf, MinLen etc. are skipped.
    """
    bounds = dict()
    for constraint in metadata:
        for kind in ("ge", "gt", "le", "lt"):
            value = getattr(constraint, kind, None)
            if value is not None:
                bounds[kind] = value

    if "ge" in bounds and "le" in bounds:
        return f"between {bounds['ge']} and {bounds['le']} (inclusive)"
    if "gt" in bounds and "lt" in bounds:
        return f"between {bounds['gt']} and {bounds['lt']} (exclusive)"

    phrases = list()
    if "ge" in bounds:
        phrases.append(f"{bounds['ge']} or greater")
    if "gt" in bounds:
        phrases.append(f"greater than {bounds['gt']}")
    if "le" in bounds:
        phrases.append(f"{bounds['le']} or less")
    if "lt" in bounds:
        phrases.append(f"less than {bounds['lt']}")
    return " and ".join(phrases)

def _number_to_string(label: str, metadata: Iterable[Any]) -> str:
    bounds = bounds_to_string(metadata)
    return f"{label} {bounds}" if bounds else label

def type_to_string(tp: Any, metadata: Iterable[Any] = ()) -> str:
    """
    A field's type in words. `metadata` is the field's FieldInfo.metadata (numeric bounds).
    Bounds belong to the field, so they are not passed down to a list's element type.
    """
    base, is_optional = _unwrap_optional(tp)
    if get_origin(base) is list:
        args = get_args(base)
        inner = type_to_string(args[0]) if args else "Any"
        rendered = f"A list of [{inner}]"
    elif _is_enum(base):
        rendered = f"{base.__name__} (Choice Value)"
    elif base is bool:
        rendered = "True or False"
    elif base is str:
        rendered = "Plaintext string"
    elif base is int:
        rendered = _number_to_string("Integer number", metadata)
    elif base is float:
        rendered = _number_to_string("Decimal number", metadata)
    elif isinstance(base, type):
        rendered = base.__name__
    else:
        rendered = str(base).replace("typing.", "")
    if is_optional:
        return f"Optional mention of [{rendered}]"
    return rendered

#-----------------------------------------------------------------------------
# Walk the model
#-----------------------------------------------------------------------------
def _walk(model: type[pydantic.BaseModel], level: int, indent: str,
          exclude_fields: frozenset[str], path: tuple[type, ...]) -> list[str]:
    """
    One block of lines per field of `model`, nested models indented one level deeper.
    `path` holds the models being expanded, so a self-referencing model stops instead of
    recursing forever.
    """
    lines = list()
    for name, field in model.model_fields.items():
        if name in exclude_fields:
            continue
        current = indent * level
        nested, is_list = _model_type(field.annotation)
        if nested:
            if is_list:
                lines.append(f"{current}{name}: A (possibly empty) list of {nested.__name__} instances, which contain:")
            else:
                lines.append(f"{current}{name}:")
            if nested in path:
                lines.append(f"{current}{indent}# {nested.__name__} (recursive, described above)")
            else:
                lines.extend(_walk(nested, level + 1, indent, exclude_fields, path + (nested,)))
            lines.append("")
            lines.append("")
            continue

        lines.append(f"{current}{name} = {type_to_string(field.annotation, field.metadata)}")

        comments = list()
        if field.description:
            comments.append(field.description)
        enum_type = _enum_type(field.annotation)
        if enum_type:
            comments.append("Possible Values:")
            for member in enum_type:
                comments.append(f"  - {member.value}")
        for comment in comments:
            lines.append(f"{current}{indent}# {comment}")
    return lines

def summarize(annotation: pydantic.BaseModel | type[pydantic.BaseModel], *,
              exclude_fields: Iterable[str] = (),
              indent: str = INDENT) -> str:
    """
    Text summary of an annotation model (class or instance).
    :param exclude_fields: field names to leave out wherever they appear, e.g. {'has_mention', 'spans'}
    :param indent: one level of indentation
    """
    model = annotation if isinstance(annotation, type) else annotation.__class__
    lines = [f'model = "{model.__name__}"']
    lines.extend(_walk(model, 0, indent, frozenset(exclude_fields), (model,)))
    return "\n".join(lines) + "\n"

def save_summary(annotation: pydantic.BaseModel | type[pydantic.BaseModel],
                 file_path: Path | str, *,
                 exclude_fields: Iterable[str] = (),
                 indent: str = INDENT) -> Path:
    """Write summarize(annotation) to file_path, creating the output directory."""
    file_path = Path(file_path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(summarize(annotation, exclude_fields=exclude_fields, indent=indent),
                         encoding="utf-8")
    return file_path
