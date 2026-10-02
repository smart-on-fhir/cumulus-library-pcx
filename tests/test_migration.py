"""Portable migration contracts. Only synthetic inputs and local generation are used."""
import csv
import hashlib
import json
import tomllib
from pathlib import Path

import msgspec
import pytest
import sqlglot
from sqlglot import exp
from sqlglot.optimizer.qualify import qualify
from cumulus_library import CountsBuilder, StudyManifest
from cumulus_library.builders.nlp.workflow import NlpWorkflow
from cumulus_study_builder.config import get_config
from cumulus_study_builder.tools import filetool, study_builder
from cumulus_study_builder.validation import validate_inputs

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = json.loads((ROOT / 'tests/legacy_contract.json').read_text())


def test_input_and_schema_contracts(generated_study):
    assert validate_inputs() == []
    for name, digest in CONTRACT['input_sha256'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest, name
    for name, digest in CONTRACT['schema_sha256'].items():
        content = json.loads(filetool.path_llm('schemas/'+name).read_text())
        assert hashlib.sha256(json.dumps(content,sort_keys=True).encode()).hexdigest() == digest, name
    for name, expected in CONTRACT['workflows'].items():
        path = filetool.path_project(name)
        assert tomllib.loads(path.read_text()) == expected, name
        msgspec.toml.decode(path.read_bytes(),type=NlpWorkflow)
        for cfg in expected['tables'].values():
            assert filetool.path_project(cfg['response_schema']).is_file()
    assert not (ROOT/'study/tools').exists()
    for path in (ROOT/'study').rglob('*.py'):
        assert 'from cumulus_library_' not in path.read_text(), path


def test_cumulus_manifest_and_count_contracts():
    # Export actions name the counts workflow; cumulus-library expands it to its tables.
    manifest = StudyManifest(ROOT/'study')
    manifest.materialize_counts_builder_exports()
    counts=[export.name for export in manifest.get_export_table_list() if export.export_type=='cube']
    assert sorted(counts)==sorted(CONTRACT['count_tables'])


def counts_queries(workflow: Path) -> list[str]:
    """SQL cumulus-library renders from a counts workflow, one CREATE TABLE per table."""
    manifest=StudyManifest(ROOT/'study')
    builder=CountsBuilder(manifest,toml_config_path=workflow)
    builder.prepare_queries(config=None,manifest=manifest)
    return builder.queries


def _walk(*, default_only=False):
    study=ROOT/'study'
    manifest=tomllib.loads((study/'manifest.toml').read_text())
    prefix=manifest['study_prefix']+'__'
    schema={t:dict.fromkeys(cols,'UNKNOWN') for t,cols in json.loads((ROOT/'tests/column_contracts.json').read_text()).items()}
    known=set(CONTRACT['external_selectors'])
    # Site-supplied selectors carry the columns study/nlp-selection-requirements.json requires.
    requirements=json.loads((study/'nlp-selection-requirements.json').read_text())
    for table in requirements['tables']:
        schema[table]=dict.fromkeys(requirements['required_columns'],'UNKNOWN')
    raw_columns=['note_ref','subject_ref','encounter_ref','generated_on','task_version','system_fingerprint','result']

    def check_sql(text,source_file):
        for tree in sqlglot.parse(text,read='trino'):
            if tree is None:continue
            target=tree.this.name if isinstance(tree,exp.Create) else None
            ctes={c.alias for c in tree.find_all(exp.CTE)}
            refs={t.name for t in tree.find_all(exp.Table)}-{target}-ctes
            assert not ({r for r in refs if r.startswith(prefix)}-known), (source_file,refs-known)
            if target:
                query=tree.expression.copy()
                # SQLGlot reads Trino's bare CURRENT_SCHEMA as a column.
                query=query.transform(lambda n: exp.CurrentSchema() if isinstance(n,exp.Column) and not n.table and n.name.lower()=='current_schema' else n)
                result=qualify(query,schema=schema,dialect='trino',infer_schema=False)
                assert len(result.named_selects)==len(set(result.named_selects)),(source_file,'duplicate output columns')
                schema[target]=dict.fromkeys(result.named_selects,'UNKNOWN');known.add(target)

    for stage,entries in manifest['stages'].items():
        for entry in entries:
            if default_only and entry.get('skip_by_default'):continue
            for filename in entry['files']:
                path=study/filename
                if entry.get('type')!='submanifest':
                    workflow=tomllib.loads(path.read_text())
                    if workflow.get('config_type')=='nlp':
                        for task,cfg in workflow['tables'].items():
                            if selector:=cfg.get('select_by_table'):
                                assert selector in known, (stage,selector)
                            for deployment in get_config().nlp_deployments:
                                raw=prefix+'nlp_'+task+'_'+deployment
                                known.add(raw);schema[raw]=dict.fromkeys(raw_columns,'UNKNOWN')
                    continue
                for action in tomllib.loads(path.read_text())['actions']:
                    for source_file in action.get('files',[]):
                        source=study/source_file
                        assert source.is_file(),source
                        if source.suffix=='.workflow':
                            assert tomllib.loads(source.read_text())['config_type']=='counts',source
                            for sql in counts_queries(source):
                                check_sql(sql,source_file)
                            continue
                        if source.suffix=='.toml':
                            upload=tomllib.loads(source.read_text())
                            assert upload.get('config_type')=='file_upload',source
                            for table,cfg in upload['tables'].items():
                                with (source.parent/(cfg['files'][0] if 'files' in cfg else cfg['file'])).open(newline='',encoding='utf-8-sig') as handle:
                                    columns=next(csv.reader(handle))
                                assert len(columns)==len(cfg['col_types']),source
                                schema[prefix+table]=dict.fromkeys(columns,'UNKNOWN');known.add(prefix+table)
                        elif source.suffix=='.sql':
                            check_sql(source.read_text(),source_file)
                    for table in action.get('tables',[]):
                        if table.endswith('.workflow'):
                            for name in tomllib.loads((study/table).read_text())['tables']:
                                assert prefix+name in known,(stage,name)
                        else:
                            assert table in known,(stage,table)


@pytest.mark.parametrize('default_only',[False,True])
def test_sql_columns_and_execution_order(default_only):
    _walk(default_only=default_only)


def test_repeat_build_is_stable():
    def snapshot():
        return {str(p.relative_to(ROOT)):p.read_bytes() for parent in [ROOT/'study/sql/generated', ROOT/'study/llm/schemas'] for p in parent.glob('*') if p.is_file()} | {str(p.relative_to(ROOT)):p.read_bytes() for p in (ROOT/'study').glob('*.toml')}
    before=snapshot()
    study_builder.make_study()
    assert snapshot()==before
