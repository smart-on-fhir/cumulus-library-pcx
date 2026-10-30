# Installing PCX

How a site installs or upgrades the `cumulus-library-pcx` study package. To build the study
from source, see [cumulus-study.md](cumulus-study.md).

## Pre-requirements

See [Prerequisite studies](cumulus-study.md#prerequisite-studies) in cumulus-study.md.
These must already be built in your warehouse:

- [cumulus-library](https://github.com/smart-on-fhir/cumulus-library) (the `core` study)
- [RxNorm](https://github.com/smart-on-fhir/cumulus-library-rxnorm)
- [LOINC](https://github.com/smart-on-fhir/cumulus-library-loinc)

## 1. First-time install (CHOP)

```sh
pip install cumulus-library-pcx==0.5.3
```

## 2. Upgrade (CHOP)

Remove the prior PCX tables, then replace the package.

```sh
cumulus-library clean --target pcx
pip uninstall -y cumulus-library-pcx
pip install cumulus-library-pcx==0.5.3
```
