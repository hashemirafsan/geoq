# GeoQ

GeoQ is a CLI-first geospatial file-native query engine written in Elixir.

Current status: Docker-first development and production-grade macOS install pipeline via Homebrew.

## Install on macOS (Homebrew)

```bash
brew tap hashemirafsan/geoq
brew install geoq
geoq --version
geoq doctor
```

## Quick Start (Docker)

All commands run inside containers so host dependencies are not required.

```bash
make docker-build
make deps
make compile
make test
make data-check
```

## Common Commands

```bash
make shell        # interactive dev shell
make format       # code formatting
make format-check # check formatting only
make lint         # credo checks
make test         # tests with coverage report
make ci           # full docker-based CI checks
make acceptance-smoke # real user journey smoke
```

## CI

- GitHub Actions workflow: `.github/workflows/ci.yml`
- Uses the same Docker + Make workflow as local development.
- Release workflow: `.github/workflows/release.yml` (tag `v*`).

## Project Docs

- Architecture vision: `architecture.md`
- Task board and checklist: `task-board.md`
- Docker setup walkthrough: `docs/00-quickstart-docker.md`
- Testing strategy and policy: `docs/03-testing-strategy.md`
- Debugging playbook: `docs/04-debugging-playbook.md`
- Contributor checklist: `docs/05-contributor-checklist.md`
- Release checklist: `docs/release-checklist.md`
- Rollback guide: `docs/rollback.md`
- Data exploration notes: `docs/06-data-playground.md`

## Notes

- Registry aliases persist to `~/.geoq/registry.json`.
- Release flow updates Homebrew formula with pinned tag tarball + sha256.
