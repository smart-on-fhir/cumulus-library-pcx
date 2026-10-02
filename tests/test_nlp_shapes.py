"""Bind the migrated wide/highlight SQL to the real JSON-schema shape, using synthetic rows."""
import json
from pathlib import Path
import tomllib
import duckdb
import sqlglot
from sqlglot import exp
from cumulus_study_builder.tools import filetool

def schema_type(node, definitions, name=''):
    if name == 'spans':
        # Cumulus NLP resolves the model's verbatim quotes into character offsets.
        return 'BIGINT[][]'
    if '$ref' in node:
        return schema_type(definitions[node['$ref'].split('/')[-1]], definitions, name)
    if 'anyOf' in node:
        return schema_type(next(n for n in node['anyOf'] if n.get('type') != 'null'), definitions, name)
    kind = node.get('type')
    if kind == 'object':
        return 'STRUCT(' + ','.join(f'"{k}" {schema_type(v,definitions,k)}' for k,v in node['properties'].items()) + ')'
    if kind == 'array':
        return schema_type(node['items'],definitions) + '[]'
    return {'boolean':'BOOLEAN','integer':'BIGINT','number':'DOUBLE'}.get(kind,'VARCHAR')


def response(node, definitions, name=''):
    if name == 'spans': return [[0,4]]
    if '$ref' in node: return response(definitions[node['$ref'].split('/')[-1]], definitions, name)
    if 'anyOf' in node: return response(next(n for n in node['anyOf'] if n.get('type') != 'null'), definitions, name)
    if 'enum' in node: return node['enum'][0]
    kind=node.get('type')
    if kind=='object': return {k:response(v,definitions,k) for k,v in node['properties'].items()}
    if kind=='array': return [response(node['items'],definitions)]
    if kind=='boolean': return True
    if kind in {'integer','number'}: return 1
    return '2020-01-01' if 'date' in name else 'synthetic'



def test_all_raw_projections_bind_and_reject_unknown_versions():
    root = filetool.path_project()
    prefix = tomllib.loads((root/'manifest.toml').read_text())['study_prefix']
    sources = {}
    for workflow in root.glob('*.workflow'):
        for task, cfg in tomllib.loads(workflow.read_text())['tables'].items():
            entry = sources.setdefault(task, dict(schema=cfg['response_schema'], versions=set()))
            entry['versions'].add(cfg['version'])
    with duckdb.connect() as db:
        db.execute('CREATE MACRO array_min(a) AS list_min(a); CREATE MACRO array_max(a) AS list_max(a)')
        available = set()
        for task, cfg in sources.items():
            schema = json.loads((root/cfg['schema']).read_text())
            dtype = schema_type(schema, schema.get('$defs', {}))
            payload = json.dumps(response(schema, schema.get('$defs', {})))
            table = f'{prefix}__nlp_{task}_gpt_oss_120b'
            available.add(table)
            db.execute(f'CREATE TABLE {table}(note_ref VARCHAR, subject_ref VARCHAR, encounter_ref VARCHAR, generated_on VARCHAR, task_version BIGINT, system_fingerprint VARCHAR, result {dtype})')
            for version in sorted(cfg['versions'] | {-1}):
                db.execute(f'INSERT INTO {table} VALUES (?,?,?,?,?,?,CAST(? AS {dtype}))',
                           [f'note-v{version}', 'synthetic-subject', 'synthetic-encounter', '2020-01-01', version, 'synthetic', payload])
        tested = []
        for path in sorted(filetool.path_sql_generated().glob(prefix+'__llm_*.sql')):
            tree = sqlglot.parse_one(path.read_text(), read='trino')
            ctes = {c.alias for c in tree.find_all(exp.CTE)}
            refs = {t.name for t in tree.find_all(exp.Table)} - {tree.this.name} - ctes
            if not refs or not refs <= available:
                continue  # Dependent cohort/timeline queries have their own column-contract tests.
            db.execute(sqlglot.transpile(path.read_text(), read='trino', write='duckdb')[0])
            available.add(tree.this.name)
            columns = [row[0] for row in db.execute(f'SELECT * FROM {tree.this.name} LIMIT 0').description]
            assert 'note_ref' in columns, path
            assert not db.execute(f"SELECT 1 FROM {tree.this.name} WHERE note_ref = 'note-v-1'").fetchall(), path
            tested.append(path.name)
        assert len(tested) == 23, tested
