# 1. Virtual Env
```commandline
python3 -m venv pcx && source pcx/bin/activate
```

# 2. pip install
```commandline
pip install cumulus_library_pcx-0.4.0-py3-none-any.whl
```

## 3. Build SQL
```commandline
cumulus-library build -t pcx --stage all                                  
```

--- 
## Release notes

### Pre-release only
Goal of this pre-release is to get CHOP setup.    

### CHOP specific patient list

> Default PCX patient list is **generated** using FHIR coded data.
> 
> CHOP can augment this list to use local knowledge

See: `cumulus_library_pcx/casedef.toml` 
* cumulus_library_pcx/sql/**generated**/pcx__cohort_casedef_include.sql
* cumulus_library_pcx/sql/**custom**/pcx__cohort_casedef_include.sql

### LLM on Bedrock

After step #3 build,  `pcx__sample_task` table in Athena should now contain many `note_ref` to process with LLM. 
