# GeoQ

GeoQ is a CLI-first geospatial file-native query engine written in Elixir.

Current status: project skeleton with Docker-first development workflow.

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
```

## CI

- GitHub Actions workflow: `.github/workflows/ci.yml`
- Uses the same Docker + Make workflow as local development.

## Project Docs

- Architecture vision: `architecture.md`
- Task board and checklist: `task-board.md`
- Docker setup walkthrough: `docs/00-quickstart-docker.md`
- Data exploration notes: `docs/06-data-playground.md`

## Notes

- Query/adapters/spatial modules are currently placeholders.
- Implementation proceeds by vertical slices from the task board.
- Registry aliases persist to `~/.geoq/registry.json` (Docker volume-backed in `dev` service).

## Future Package Installation

If published to Hex later, dependency installation will be added here.

```elixir
def deps do
  [
    {:geoq, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/geoq>.
