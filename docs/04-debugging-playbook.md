# Debugging Playbook

This page covers common issues for Docker, Homebrew installs, and adapter runtime tools.

## 1) Quick triage

Run:

```bash
geoq --version
geoq doctor
```

If `doctor` fails, fix missing external tools first.

## 2) Docker development issues

- dependency/network timeout:
  - rerun `make deps`
- stale cache issues:
  - `make clean-cache`
  - `make docker-build`
- fixture issues:
  - `make prepare-test-fixtures`

## 3) Homebrew/macOS issues

- formula install fails:
  - run `brew update`
  - run `brew doctor`
  - retry `brew install geoq`
- runtime command missing:
  - `geoq doctor`
  - reinstall deps: `brew install gdal netcdf erlang`

## 4) Common query/runtime failures

- `source not registered`:
  - run `geoq list`
  - register file first
- `unknown column`:
  - inspect source schema:
    - `geoq inspect <file>`
- duplicate alias:
  - unregister old alias or choose a new alias

## 5) CI failures

- run local parity checks:

```bash
make ci
make acceptance-smoke
```

- if only macOS install-smoke fails, reproduce with Homebrew locally.
