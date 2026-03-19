# Quickstart: Docker Development

This guide runs GeoQ development fully inside Docker so your host machine stays clean.

## 1) Prerequisites

- Docker Desktop (or Docker Engine + Compose)

Check:

```bash
docker --version
docker compose version
```

## 2) Build the image

From project root:

```bash
make docker-build
```

What this installs in the container:

- Elixir + Erlang runtime
- `gdal-bin` for GeoTIFF tooling
- `netcdf-bin` and `libnetcdf-dev` for NetCDF tooling

## 3) Open a dev shell

```bash
make shell
```

You will be inside `/workspace` with the project mounted.

## 4) Validate sample data tools

The repository includes a `data/` folder with `.tif`, `.nc`, `.csv`, and `.shp` assets.

Run a quick check:

```bash
make data-check
```

Manual checks:

```bash
docker compose run --rm dev bash -lc "bash scripts/prepare_test_fixtures.sh && gdalinfo data/fixture_small.tif"
docker compose run --rm dev ncdump -h data/HWD_EU_health_rcp85_mean_v1.0.nc
```

## 5) Standard workflow commands

- `make deps` - fetch Mix dependencies
- `make compile` - compile app
- `make test` - run tests in container
- `make cover` - run tests with coverage
- `make format` - apply formatter
- `make format-check` - verify formatting (CI mode)
- `make lint` - run Credo lint checks
- `make prepare-test-fixtures` - create local test fixtures when data files are absent
- `make ci` - run Docker build + format-check + lint + tests
- `make clean-cache` - remove Compose volumes/caches

## 6) Run the first GeoQ inspect command

GeoQ currently has `.nc` and `.shp` inspect support.

```bash
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"inspect\", \"data/HWD_EU_health_rcp85_mean_v1.0.nc\"])'"
```

JSON output:

```bash
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"inspect\", \"--format\", \"json\", \"data/HWD_EU_health_rcp85_mean_v1.0.nc\"])'"
```

Shapefile inspect:

```bash
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"inspect\", \"data/gadm41_GRC_shp/gadm41_GRC_0.shp\"])'"
```

Registry persistence check:

```bash
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"register\", \"data/HWD_EU_health_rcp85_mean_v1.0.nc\", \"--alias\", \"climate\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"list\"])'"
```

The registry file is persisted at `~/.geoq/registry.json` inside the container and backed by a named Docker volume.

If you try to register the same alias again, GeoQ returns an `alias_exists` error to prevent accidental overwrite.

Minimal query check (current metadata-backed slice):

```bash
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"query\", \"SELECT * FROM climate LIMIT 1\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"query\", \"--format\", \"csv\", \"SELECT file_path FROM climate LIMIT 1\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"query\", \"SELECT time FROM climate LIMIT 3\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"query\", \"--format\", \"json\", \"--compact\", \"SELECT time FROM climate LIMIT 1\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"register\", \"data/fixture_small.tif\", \"--alias\", \"raster\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"query\", \"SELECT band_1 FROM raster LIMIT 2\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"register\", \"data/gadm41_GRC_shp/gadm41_GRC_0.shp\", \"--alias\", \"regions\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"query\", \"SELECT COUNTRY FROM regions LIMIT 1\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"query\", \"--max-cell-length\", \"40\", \"SELECT geom FROM regions LIMIT 1\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"query\", \"--no-truncate\", \"SELECT geom FROM regions LIMIT 1\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"unregister\", \"raster\"])'"
docker compose run --rm dev bash -lc "mix run -e 'GeoQ.CLI.main([\"unregister\", \"regions\"])'"
```

Notes:

- JSON query output defaults to pretty printing; use `--compact` for single-line JSON.
- Table output truncates very long values (like WKT geometry) to keep terminal output readable.
- Use `--no-truncate` to print full values, or `--max-cell-length <n>` to tune truncation length.

## 7) Notes on speed and reproducibility

- Compose uses named volumes for `_build`, `deps`, Hex, and Rebar caches.
- First build is slower; later runs are faster due to cached layers/volumes.

## 8) Troubleshooting

- If dependency fetch fails due to network hiccups, rerun `make deps`.
- If cache gets corrupted, run `make clean-cache` then `make docker-build`.
- If file permissions look odd on macOS, use Docker Desktop default file sharing.
