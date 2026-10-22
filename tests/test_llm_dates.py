"""LLM date strings as DATEs: the rules in sql/template/date_macros.sql.jinja, run in DuckDB
the same way test_nlp_shapes runs the wide tables (rendered for Athena, transpiled by sqlglot).
"""
from datetime import date

import duckdb
import sqlglot
from cumulus_study_builder.tools import template

# value as the LLM wrote it, stated precision, expected <name>_day, expected <name>_day_precision
CASES = [
    ('2020-09-15', 'DAY',   date(2020, 9, 15), 'DAY'),
    ('2020-09-01', 'MONTH', date(2020, 9, 1),  'MONTH'),
    ('2020-09',    'MONTH', date(2020, 9, 1),  'MONTH'),
    ('2020',       'YEAR',  date(2020, 1, 1),  'YEAR'),
    ('2020-01-01', 'YEAR',  date(2020, 1, 1),  'YEAR'),
    # the coarser of the shape and the stated precision wins, at the start of its period
    ('2020-09-15', 'MONTH', date(2020, 9, 1),  'MONTH'),
    ('2020-09-15', 'YEAR',  date(2020, 1, 1),  'YEAR'),
    ('2020-09',    'DAY',   date(2020, 9, 1),  'MONTH'),
    ('2020',       'DAY',   date(2020, 1, 1),  'YEAR'),
    ('2020-09-15', None,    date(2020, 9, 15), 'DAY'),
    ('2020-09',    None,    date(2020, 9, 1),  'MONTH'),
    # not understood: NULL day and precision (pcx__warn_llm_date_invalid lists them)
    ('202?-05-23', 'DAY',   None, None),
    ('10-30',      None,    None, None),
    ('2020-9-15',  'DAY',   None, None),
    ('2020-09-15T08:00', 'DAY', None, None),
    (' 2020-09-15', 'DAY',  None, None),
    ('Sept 2020',  'MONTH', None, None),
    # the month and day must exist on the calendar
    ('2024-02-30', 'DAY',   None, None),
    ('2024-02-30', 'YEAR',  None, None),
    ('2023-02-29', 'DAY',   None, None),
    ('2024-02-29', 'DAY',   date(2024, 2, 29), 'DAY'),
    ('2000-02-29', 'DAY',   date(2000, 2, 29), 'DAY'),
    ('1900-02-29', 'DAY',   None, None),
    ('2020-04-31', 'DAY',   None, None),
    ('2020-12-31', 'DAY',   date(2020, 12, 31), 'DAY'),
    ('2020-09-00', 'DAY',   None, None),
    ('2020-13',    'MONTH', None, None),
    ('2020-00',    'MONTH', None, None),
    # plausible only from 1980-01-01 to the build day
    ('1980-01-01', 'DAY',   date(1980, 1, 1),  'DAY'),
    ('1979-12-31', 'DAY',   None, None),
    ('1979',       'YEAR',  None, None),
    ('2999-01-01', 'DAY',   None, None),
    ('2999',       'YEAR',  None, None),
    ('',           None,    None, None),
    (None,         'YEAR',  None, None),
    (None,         None,    None, None),
]


def literal(value: str | None) -> str:
    return 'CAST(NULL AS VARCHAR)' if value is None else "'" + value.replace("'", "''") + "'"


def parse(rows: list[tuple]) -> list[tuple]:
    """Run llm_day_columns over (value, stated) rows, in order."""
    values = ', '.join(f'({i}, {literal(v)}, {literal(p)})' for i, (v, p) in enumerate(rows))
    sql = template.environment().from_string(
        "{%- import 'date_macros.sql.jinja' as dates -%}\n"
        "SELECT  {{ dates.llm_day_columns('src.raw', 'src.stated', 'parsed_day') }}\n"
        "FROM    (VALUES " + values + ") AS src (pos, raw, stated)\n"
        "ORDER BY src.pos").render()
    return duckdb.execute(sqlglot.transpile(sql, read='trino', write='duckdb')[0]).fetchall()


def test_understood_dates_start_their_period_and_others_are_null():
    got = parse([(v, p) for v, p, _, _ in CASES])
    for (value, stated, day, precision), row in zip(CASES, got):
        assert row == (day, precision), (value, stated)


def test_year_and_month_dates_sort_on_or_before_day_dates():
    year, month, day = (row[0] for row in parse([('2020', 'YEAR'), ('2020-09', 'MONTH'), ('2020-09-15', 'DAY')]))
    assert year <= month <= day


def test_every_day_of_two_years_is_understood():
    """2023 and 2024 (a leap year), every calendar day, plus the day after each month ends."""
    from datetime import timedelta
    days = [date(2023, 1, 1) + timedelta(n) for n in range(731)]
    got = parse([(d.isoformat(), 'DAY') for d in days])
    assert got == [(d, 'DAY') for d in days]
    month_ends = [d for d in days if (d + timedelta(1)).day == 1]
    over = [f'{d.year}-{d.month:02d}-{d.day + 1:02d}' for d in month_ends if d.day < 31]
    assert parse([(v, 'DAY') for v in over]) == [(None, None)] * len(over)


def test_today_is_plausible_and_tomorrow_is_not():
    from datetime import timedelta
    today = date.today()
    tomorrow = today + timedelta(1)
    assert parse([(today.isoformat(), 'DAY'), (tomorrow.isoformat(), 'DAY')]) == [(today, 'DAY'), (None, None)]
