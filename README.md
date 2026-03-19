# GeoQ

GeoQ is a CLI-first geospatial file-native query engine written in Elixir.

Current status: Docker-first development and production-grade macOS install pipeline via Homebrew.

## Install on macOS (Homebrew)

```bash
brew untap hashemirafsan/geoq 2>/dev/null || true
brew tap hashemirafsan/geoq https://github.com/hashemirafsan/geoq
brew install hashemirafsan/geoq/geoq
geoq --version
geoq doctor
```

Note: we use an explicit tap URL because this formula lives in `hashemirafsan/geoq`
instead of the default `homebrew-geoq` repository naming convention.

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

## Verification

- Run local checks with `make ci`.
- Run end-user smoke with `make acceptance-smoke`.
- Initial production releases are performed locally using `make release-local VERSION=vX.Y.Z`.

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
