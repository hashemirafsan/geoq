# Testing Strategy

This document defines how GeoQ tests are organized, how to run them, and what
quality rules we enforce.

## Goals

- keep tests deterministic and easy to debug
- run the same checks locally and in CI
- grow coverage safely toward 100%
- ensure error tuple paths are tested, not just happy paths

## Test Categories

GeoQ uses four test categories:

1. Unit tests
   - small module-level behavior
   - examples: lexer, parser, formatter helpers

2. Contract tests
   - behavior/callback conformance for adapters
   - examples: NetCDF and Shapefile adapter read/schema functions

3. Integration tests
   - multi-module flows via CLI and query pipeline
   - examples: register -> query -> formatter output

4. Regression tests
   - tests added for fixed bugs to prevent reintroduction
   - every bug fix should include a failing test first (or equivalent)

## Deterministic Test Helpers

- `test/test_helper.exs` starts ExUnit with fixed seed (`seed: 0`).
- Shared helper utilities live in `test/support/test_support.exs`.
- Registry tests use unique global names and unique temp storage paths to avoid
  cross-test interference.

## Fixture Strategy

Current CI/local strategy:

- `scripts/prepare_test_fixtures.sh` generates minimal fixtures in `data/` when
  files are missing:
  - NetCDF fixture (`.nc`)
  - Shapefile fixture (`.shp` + sidecar files)
  - CSV fixture (`.csv`)

Why this exists:

- `data/` is git-ignored (large local datasets)
- CI still needs deterministic fixture inputs

Planned follow-up:

- move small canonical fixtures to `priv/sample_data` and keep script fallback
  for local convenience

## Error-Path Testing Policy

Policy: each user-facing `{:error, ...}` branch must have at least one test.

Examples already covered:

- unknown command / invalid args
- duplicate alias and missing file
- unknown source alias in planner/executor
- unknown projection columns in adapters
- corrupted registry file handling

When adding new code:

1. implement success-path test
2. implement at least one failure-path test for each returned error tuple
3. keep error messages actionable in CLI output

## Coverage Gates

- coverage is checked in CI via `mix test --cover`
- threshold is currently set in `mix.exs` (`test_coverage.summary.threshold`)
- threshold should be ratcheted upward regularly toward 100%

## Commands

Use Docker-first commands:

```bash
make format-check
make lint
make test
make ci
```

`make ci` is the canonical pre-PR command and matches GitHub Actions behavior.
