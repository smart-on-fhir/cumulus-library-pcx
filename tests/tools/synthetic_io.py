"""Study-independent fixture loading and Athena-style CSV export.

Callers provide schema SQL, ordered stage SQL, table rows and output paths.
No clinical assumptions, repository paths or table prefixes live here.
DuckDB is imported only when building a test database.
"""
import csv
import tomllib
from collections.abc import Iterable, Mapping
from pathlib import Path


def list_stage_sql(project_dir: Path, stages: Iterable[str], *, sql_prefix: str) -> list[Path]:
    """Read SQL entries from flat action manifests, preserving their build order."""
    files = []
    for stage in stages:
        with (project_dir / stage).open('rb') as handle:
            for action in tomllib.load(handle)['actions']:
                files.extend(project_dir / name for name in action['files']
                             if name.startswith(sql_prefix))
    return files


def write_plain_csv(path: Path, columns: list[str], rows: Iterable[Mapping]) -> None:
    """Write schema-ordered fixtures; absent values and None become empty fields."""
    with path.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle)
        writer.writerow(columns)
        for row in rows:
            unknown = set(row) - set(columns)
            if unknown:
                raise KeyError(f'{path.stem}: columns not in schema.sql: {sorted(unknown)}')
            writer.writerow(['' if row.get(col) is None else row.get(col) for col in columns])


def _identifier(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def build_database(rows: Mapping[str, list[dict]], schema: Path,
                   sql_files: Iterable[Path], input_dir: Path):
    """Load typed fixtures and execute the supplied SQL in an in-memory database.

    The caller owns the returned connection. On failure it is closed here.
    Compatibility macros cover the existing stage queries, not all Athena SQL.
    """
    import duckdb

    con = duckdb.connect()
    try:
        con.execute("CREATE MACRO array_join(a, s) AS list_aggregate(a, 'string_agg', s)")
        con.execute("CREATE MACRO date_diff(part, a, b) AS datesub(part, a, b)")
        con.execute(schema.read_text())
        schema_tables = [row[0] for row in con.execute('SHOW TABLES').fetchall()]
        unknown = set(rows) - set(schema_tables)
        if unknown:
            raise KeyError(f'tables not in schema.sql: {sorted(unknown)}')
        for table in schema_tables:
            quoted = _identifier(table)
            columns = [row[0] for row in con.execute(f'DESCRIBE {quoted}').fetchall()]
            csv_file = input_dir / f'{table}.csv'
            write_plain_csv(csv_file, columns, rows.get(table, []))
            filename = str(csv_file).replace("'", "''")
            con.execute(f"COPY {quoted} FROM '{filename}' (HEADER, DELIMITER ',', NULLSTR '')")
        for sql_file in sql_files:
            con.execute(sql_file.read_text())
    except BaseException:
        con.close()
        raise
    return con


def athena_text(value) -> str | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return 'true' if value else 'false'
    return str(value)


def export_athena_csv(con, table: str, path: Path, *, order_by: str = 'subject_ref') -> int:
    """Quote every non-null value; NULL is unquoted empty, empty text is quoted.

    Rows are ordered deterministically and streamed in batches.
    """
    cursor = con.execute(f'SELECT * FROM {_identifier(table)} ORDER BY {_identifier(order_by)}')
    columns = [col[0] for col in cursor.description]
    count = 0
    with path.open('w', newline='', encoding='utf-8') as handle:
        handle.write(','.join('"' + col.replace('"', '""') + '"' for col in columns) + '\n')
        while rows := cursor.fetchmany(1000):
            for row in rows:
                fields = []
                for value in row:
                    text = athena_text(value)
                    fields.append('' if text is None else '"' + text.replace('"', '""') + '"')
                handle.write(','.join(fields) + '\n')
            count += len(rows)
    return count
