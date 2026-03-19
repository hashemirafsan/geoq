# GeoQ Task Board (Docker-First, Docs-First, 100% Coverage)

## Project Objective
Build GeoQ v1 as a CLI geospatial file-native query engine in Elixir, fully runnable and testable in Docker, with beginner-friendly documentation and 100% test coverage.

## Definition of Done (Global)
- [x] Runs fully in Docker (no host dependency required for normal dev/test)
- [x] CI uses the same Docker workflow as local
- [ ] All user-facing features documented with examples
- [ ] 100% test coverage on project code
- [ ] Error paths covered and documented
- [ ] Architecture and learning docs understandable for non-Elixir contributors

---

## Milestone Order
- [x] M1: Scope + Docker baseline + Quickstart docs
- [ ] M2: Skeleton app + test/coverage gates
- [x] M3: First vertical slice (`register`, `list`, `inspect`, simple `query`)
- [ ] M4: Full query engine + adapters
- [ ] M5: Spatial joins + output formats + REPL
- [ ] M6: Hardening (CI, benchmarks, docs polish, release checklist)

---

## Epic A - Scope & Planning
- [ ] Convert `architecture.md` into explicit v1 scope checklist (in/out)
- [ ] Map architecture success criteria to testable acceptance criteria
- [ ] Define PR checklist and quality gates
- [ ] Create contributor workflow doc (branch -> test -> PR)
- [ ] Add risk register (external tools, sample data, parser complexity)

## Epic B - Docker Environment (Highest Priority)
- [x] Create `Dockerfile` for Elixir/Erlang with `gdal-bin` and `netcdf-c`
- [x] Add `docker-compose.yml` with `dev` and `test` services
- [x] Add volume caching for Mix deps/build artifacts
- [x] Add convenience commands (`make` or scripts) for `deps`, `compile`, `test`, `cover`, `shell`
- [x] Verify clean-machine setup works end-to-end
- [x] Document Docker troubleshooting (permissions/cache/network)

## Epic C - Project Bootstrap
- [x] Initialize Mix app and supervision tree
- [x] Create namespace/module structure from architecture plan
- [x] Add CLI command routing stubs (`register`, `unregister`, `list`, `inspect`, `query`, `repl`)
- [x] Ensure app compiles and boots in container
- [x] Add formatter and lint baseline config

## Epic D - Test & Coverage Infrastructure
- [x] Configure ExUnit defaults and deterministic test helpers
- [x] Configure coverage reports (`mix test --cover`, ExCoveralls optional)
- [x] Add coverage gate in CI (ratchet to 100%)
- [x] Define test categories: unit / contract / integration / regression
- [x] Add policy: every `{:error, ...}` path must have a test
- [x] Add CI fixture generation strategy (`scripts/prepare_test_fixtures.sh`)
- [ ] Add sample fixture strategy under `priv/sample_data`

## Epic E - Core Types & Registry
- [x] Implement types (`Schema`, `Column`, `BBox`, `ResultSet`)
- [x] Implement `GeoQ.Registry` GenServer + ETS
- [x] Implement registry persistence adapter (JSON file)
- [x] Add tests for register/unregister/list/load-on-startup
- [x] Add tests for invalid paths, duplicate aliases, corrupted registry file

## Epic F - Inspect Command (First User Value)
- [x] Implement `inspect` for `.nc`
- [x] Implement `inspect` for `.shp`
- [x] Add `--format json` output path
- [x] Add readable table output
- [x] Add integration tests for CLI output and error messages

## Epic G - SQL Query Core
- [x] Implement lexer for v1 tokens
- [x] Implement parser for supported SQL subset
- [x] Add parser error messages for unsupported syntax
- [x] Implement planner with alias resolution and pushdown rules
- [ ] Implement executor stream pipeline with concurrency controls
- [x] Add tests: AST snapshots, planner rules, executor correctness

## Epic H - Adapters
- [x] Define shared adapter behavior contract tests
- [x] Implement NetCDF adapter `schema`
- [x] Implement NetCDF adapter `read_columns` (scalar + 1D current scope)
- [x] Implement NetCDF adapter `bbox`
- [x] Implement Shapefile adapter `schema` + `bbox`
- [x] Implement Shapefile adapter `read_columns` (attributes + `geom` WKT)
- [ ] Implement Shapefile `spatial_index` hooks
- [ ] Implement GeoTIFF adapter via GDAL Port calls
- [ ] Add resilience tests for missing/corrupt external dependencies

## Epic I - Spatial Features
- [ ] Implement `bbox(...)` predicate with pushdown-first strategy
- [ ] Implement `ST_Intersects`, `ST_Within`, `ST_Contains`, `ST_DWithin`
- [ ] Implement spatial join flow in planner/executor
- [ ] Add index build/cache/invalidation logic
- [ ] Add fixture-based spatial correctness matrix tests

## Epic J - Output & REPL
- [x] Implement formatters: `table`, `csv`, `json`
- [ ] Implement formatter: `geojson`
- [x] Ensure pipe-friendly output behavior
- [ ] Implement REPL with `.help`, `.register`, `.inspect`, `.exit`
- [ ] Improve UX errors (column suggestion, unknown alias guidance)
- [ ] Add snapshot tests for output consistency

## Epic K - Documentation (Learning-Focused)
- [x] `docs/00-quickstart-docker.md`
- [x] `docs/01-architecture-map.md`
- [ ] `docs/02-elixir-basics-for-geoq.md`
- [x] `docs/03-testing-strategy.md`
- [ ] `docs/04-debugging-playbook.md`
- [ ] `docs/05-contributor-checklist.md`
- [ ] Add "how to add a new adapter" guide

## Epic L - CI, Performance, Release
- [x] Docker-based CI pipeline (format, lint, tests, coverage)
- [ ] Enforce 100% coverage threshold
- [ ] Add benchmark smoke tests for representative workloads
- [ ] Validate architecture success criteria with executable test cases
- [ ] Add release checklist and versioning process

---

## Coverage Tracker (100% Target)
- [ ] Core types: 100%
- [ ] Registry: 100%
- [ ] CLI routing/commands: 100%
- [ ] Lexer/parser/planner/executor: 100%
- [ ] Adapters (NetCDF/Shapefile/GeoTIFF): 100%
- [ ] Spatial predicates/indexing: 100%
- [ ] Formatters + REPL: 100%
- [ ] Error paths/global exceptions-to-tuples behavior: 100%

---

## Weekly Review Checklist
- [ ] Coverage trend reviewed and gaps assigned
- [ ] Flaky tests identified and fixed
- [ ] Docs updated for all merged behavior changes
- [ ] Docker build/test time tracked and optimized
- [ ] New risks added to risk register
