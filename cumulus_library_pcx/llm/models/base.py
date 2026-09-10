from enum import StrEnum
from datetime import date
from pydantic import BaseModel, Field, model_validator

class SpanAugmentedMention(BaseModel):
    """
    A mention of a particular concept in the text, augmented with the character spans
    where the mention was found. Spans are verbatim excerpts, not numeric offsets.
    For dated fields use YYYY-MM-DD; coarse dates use the first day of the period
    with MONTH/YEAR precision. These placeholders are not exact analytic dates.
    This allows for validation of LLM-generated findings, as well as the ability to link
    mentions back to the original text for review and auditing purposes.
    """
    @model_validator(mode="after")
    def validate_evidence_and_dates(self):
        if self.has_mention != bool(self.spans) or any(not span.strip() for span in self.spans):
            raise ValueError("Mention presence must agree with nonempty verbatim evidence spans")
        for name in type(self).model_fields:
            if not name.endswith("_precision"):
                continue
            date_name = name.removesuffix("_precision")
            if date_name not in type(self).model_fields:
                continue
            value, precision = getattr(self, date_name), getattr(self, name)
            if (value is None) != (precision is None):
                raise ValueError(f"{date_name} and {name} must both be present or both null")
            if value is not None:
                parsed = date.fromisoformat(value) if isinstance(value, str) else value
                if isinstance(value, str) and parsed.isoformat() != value:
                    raise ValueError(f"{date_name} must use YYYY-MM-DD")
                if precision == DatePrecision.MONTH and parsed.day != 1:
                    raise ValueError("Month-precision dates must use the first day of the month")
                if precision == DatePrecision.YEAR and (parsed.month, parsed.day) != (1, 1):
                    raise ValueError("Year-precision dates must use January 1")
        return self

    has_mention: bool = Field(
        ...,
        description='Indicates whether the concept was mentioned in the text.'
    )
    spans: list[str] = Field(
        ...,
        description='The verbatim text where this concept was mentioned.'
    )

################################################################
# How to use DatePrecision
# $YOUR_DATE is the name of your date variable, e.g. "rx_start_date"
#
# description=
# "Precision actually supported by the source text for $YOUR_DATE. "
# "DAY: day, month, and year were explicitly stated; "
# "MONTH: month and year were explicitly stated; "
# "YEAR: only year was explicitly stated; "
# "Use Null when $YOUR_DATE is null."
################################################################
class DatePrecision(StrEnum):
    DAY = "DAY"
    MONTH = "MONTH"
    YEAR = "YEAR"
