# GeoQ — Geospatial File-Native Database Engine
## Requirements Document v0.1

---

## 1. Vision

GeoQ is a CLI-based database engine written in Elixir that treats geospatial files
(.nc, .tif, .shp, .gpkg) as queryable tables — without conversion, without ETL,
without an intermediate database. Files live on disk; GeoQ makes them SQL-queryable
in-place.

**The one-line pitch:**
> "SQLite for geospatial files — drop a .nc file, query it like a table."

---

## 2. Goals & Non-Goals

### Goals
- File-as-table abstraction: register a file, query it with SQL subset
- Support NetCDF (.nc), GeoTIFF (.tif), Shapefile (.shp) as primary formats
- Spatial predicate support: bbox filter, ST_Intersects, ST_Within
- CLI-first: usable via terminal, scriptable in shell pipelines
- BEAM-native concurrency: parallel band/chunk reads per query
- Persistent schema registry: registered files survive process restart

### Non-Goals (v1)
- Full SQL-92 compliance (no subqueries, no CTEs, no window functions)
- PostgreSQL wire protocol (future phase)
- SPARQL support (future phase)
- Write operations (INSERT, UPDATE, DELETE)
- Authentication / multi-user access

---

## 3. CLI Interface

### 3.1 Commands

```bash
# File Registration
geoq register rainfall.tif --alias rainfall
geoq register era5_2024.nc --alias climate
geoq register europe.shp  --alias regions
geoq unregister rainfall
geoq list                             # show all registered files + schema

# Schema Inspection
geoq inspect rainfall.tif            # columns, bands, CRS, bbox, dimensions
geoq inspect --format json era5.nc   # machine-readable output

# Query Execution
geoq query "SELECT avg(temperature) FROM climate WHERE time = '2024-01'"
geoq query "SELECT * FROM rainfall WHERE ST_Intersects(geom, regions.geom)"
geoq query "SELECT region_name, avg(value) FROM rainfall JOIN regions ON ST_Intersects(rainfall.geom, regions.geom) GROUP BY region_name"

# Query from file
geoq query --file my_query.sql

# Output formats
geoq query "..." --format table    # default: pretty-print table
geoq query "..." --format csv      # csv to stdout (pipeable)
geoq query "..." --format json     # newline-delimited JSON
geoq query "..." --format geojson  # for spatial results

# REPL
geoq repl                           # interactive session
```

### 3.2 REPL Behavior

```
$ geoq repl
GeoQ v0.1.0  |  type .help for commands

geoq> .register era5_2024.nc climate
✓ Registered: climate (124 variables, CRS: EPSG:4326)

geoq> .inspect climate
┌──────────────┬─────────────┬──────────┬──────────────────────┐
│ Column       │ Type        │ Unit     │ Dimensions           │
├──────────────┼─────────────┼──────────┼──────────────────────┤
│ temperature  │ float32     │ K        │ time × lat × lon     │
│ precipitation│ float32     │ mm/day   │ time × lat × lon     │
│ lat          │ float64     │ degrees  │ lat                  │
│ lon          │ float64     │ degrees  │ lon                  │
│ time         │ datetime    │ -        │ time                 │
└──────────────┴─────────────┴──────────┴──────────────────────┘
BBox: (-180, -90, 180, 90)  |  Time: 2024-01-01 → 2024-12-31

geoq> SELECT avg(temperature) FROM climate WHERE time = '2024-06'
Executing... ████████████████ 100%  (0.42s)

┌──────────────────┐
│ avg(temperature) │
├──────────────────┤
│ 287.34           │
└──────────────────┘

geoq> .exit
```

---

## 4. SQL Subset Specification

GeoQ implements a strict subset of SQL. Parser is custom — no external SQL parser dependency.

### 4.1 Supported Syntax

```sql
-- SELECT
SELECT col1, col2, agg_fn(col)
FROM file_alias [JOIN file_alias ON predicate]
[WHERE predicate]
[GROUP BY col]
[ORDER BY col [ASC|DESC]]
[LIMIT n]

-- Aggregate Functions
avg(col), sum(col), min(col), max(col), count(*), count(col)

-- Scalar Functions
round(col, n), abs(col), coalesce(col, default)

-- Spatial Predicates (WHERE clause)
ST_Intersects(geom_a, geom_b)
ST_Within(geom_a, geom_b)
ST_Contains(geom_a, geom_b)
ST_DWithin(geom_a, geom_b, distance_meters)
bbox(min_x, min_y, max_x, max_y)          -- fast bbox filter, no full geom needed

-- Temporal Predicates (NetCDF specific)
time = '2024-01'                          -- month resolution
time BETWEEN '2024-01-01' AND '2024-03-31'
```

### 4.2 Explicitly NOT Supported (v1)

- Subqueries
- CTEs (WITH clause)
- Window functions
- HAVING clause
- UNION / INTERSECT
- INSERT / UPDATE / DELETE

---

## 5. File Format Adapters

Each format has a dedicated adapter module implementing a common behavior.

### 5.1 Adapter Behavior Contract

```elixir
@callback schema(file_path :: String.t()) :: {:ok, Schema.t()} | {:error, term()}
@callback read_columns(file_path :: String.t(), columns :: [String.t()], filters :: [Filter.t()]) ::
            {:ok, Stream.t()} | {:error, term()}
@callback spatial_index(file_path :: String.t()) :: {:ok, Index.t()} | {:error, term()}
@callback bbox(file_path :: String.t()) :: {:ok, BBox.t()} | {:error, term()}
```

### 5.2 Format Support Matrix

| Format | Read | Schema | Spatial Filter | Temporal Filter | Band/Variable Select |
|--------|------|--------|---------------|-----------------|----------------------|
| NetCDF (.nc) | ✅ | ✅ | ✅ bbox | ✅ | ✅ |
| GeoTIFF (.tif) | ✅ | ✅ | ✅ bbox | ❌ | ✅ bands |
| Shapefile (.shp) | ✅ | ✅ | ✅ full geom | ❌ | ✅ |
| GeoPackage (.gpkg) | 🔜 v2 | 🔜 | 🔜 | ❌ | 🔜 |
| GeoParquet | 🔜 v2 | 🔜 | 🔜 | ❌ | 🔜 |

### 5.3 Elixir Library Bindings

| Format | Library | Strategy |
|--------|---------|----------|
| NetCDF | `ex_netcdf` NIF or Port to `ncdump`/`netcdf-c` | NIF preferred |
| GeoTIFF | Port to GDAL (`gdal_translate`, `gdalinfo`) | Port first, NIF later |
| Shapefile | Pure Elixir parser (simple binary format) | No external dep |
| Geometry ops | `geo` library (Elixir) | Pure Elixir |

---

## 6. Query Engine Architecture

```
Query String
     │
     ▼
┌─────────────┐
│   Lexer     │  NimbleParsec — tokenize SQL string
└──────┬──────┘
       │
┌──────▼──────┐
│   Parser    │  NimbleParsec — build AST
└──────┬──────┘
       │  {:ok, %QueryAST{}}
┌──────▼──────┐
│   Planner   │  - Resolve aliases → file paths
│             │  - Push spatial filters down to adapters
│             │  - Determine join strategy
│             │  - Estimate chunk sizes
└──────┬──────┘
       │  {:ok, %ExecutionPlan{}}
┌──────▼──────┐
│  Executor   │  - Spawn Tasks per file/chunk (BEAM concurrency)
│             │  - Merge streams
│             │  - Apply aggregates
└──────┬──────┘
       │  {:ok, %ResultSet{}}
┌──────▼──────┐
│  Formatter  │  table / csv / json / geojson
└─────────────┘
```

### 6.1 Planner Rules

1. **Filter pushdown**: spatial and temporal filters pushed to adapter before row iteration
2. **Projection pushdown**: only requested columns read from file
3. **Bbox-first**: if spatial filter present, apply bbox check before full geometry check
4. **Chunk parallelism**: large raster files split into tile chunks, read in parallel via `Task.async_stream`

### 6.2 Execution Model (Elixir-specific)

```elixir
# Each file read is a supervised Task
# GenServer holds the schema registry (ETS-backed)
# Stream-based — results do not fully materialize in memory

defmodule GeoQ.Executor do
  def execute(%ExecutionPlan{} = plan) do
    plan.sources
    |> Task.async_stream(&read_source/1, max_concurrency: System.schedulers_online())
    |> Stream.flat_map(&unwrap_result/1)
    |> apply_join(plan.join)
    |> apply_where(plan.filters)
    |> apply_aggregate(plan.aggregates)
    |> apply_order(plan.order_by)
    |> apply_limit(plan.limit)
  end
end
```

---

## 7. Spatial Index

### 7.1 Requirements
- R-tree index for vector files (Shapefile, GeoPackage)
- Bbox-grid index for raster files (tiled lookup)
- Index built on first access, cached in ETS
- Index invalidated if file mtime changes

### 7.2 Implementation
- Use `rtree` NIF or pure Elixir R-tree implementation
- ETS table per registered file: `geoq_index_{alias}`
- Warm-up: `geoq index build rainfall` (optional pre-build)

---

## 8. Schema Registry

### 8.1 Persistence
- Stored in `~/.geoq/registry.json`
- Loaded into ETS on process startup
- GenServer (`GeoQ.Registry`) manages all CRUD

### 8.2 Schema Record

```elixir
%GeoQ.Schema{
  alias: "climate",
  file_path: "/data/era5_2024.nc",
  format: :netcdf,
  columns: [
    %Column{name: "temperature", type: :float32, unit: "K", dims: [:time, :lat, :lon]},
    %Column{name: "lat", type: :float64, unit: "degrees_north", dims: [:lat]},
  ],
  bbox: {-180.0, -90.0, 180.0, 90.0},
  crs: "EPSG:4326",
  registered_at: ~U[2025-01-01 00:00:00Z],
  file_mtime: 1735689600
}
```

---

## 9. Data Types

| GeoQ Type | Elixir Representation | Notes |
|-----------|----------------------|-------|
| `float32` | `float` | Cast from binary |
| `float64` | `float` | Native |
| `int16/32` | `integer` | |
| `datetime` | `DateTime` | NetCDF time units converted |
| `point` | `%Geo.Point{}` | via `geo` library |
| `polygon` | `%Geo.Polygon{}` | via `geo` library |
| `multipolygon` | `%Geo.MultiPolygon{}` | |
| `raster_value` | `float` | Single band cell value |
| `nodata` | `nil` | Masked/nodata cells → nil |

---

## 10. Project Structure (Mix)

```
geoq/
├── mix.exs
├── mix.lock
├── config/
│   └── config.exs
├── lib/
│   ├── geoq.ex                    # Application entry
│   ├── geoq/
│   │   ├── cli.ex                 # OptionParser, command dispatch
│   │   ├── repl.ex                # IEx-style interactive loop
│   │   ├── registry.ex            # GenServer: file alias management
│   │   ├── query/
│   │   │   ├── lexer.ex           # NimbleParsec tokenizer
│   │   │   ├── parser.ex          # AST builder
│   │   │   ├── planner.ex         # Execution plan generator
│   │   │   └── executor.ex        # Task-based parallel execution
│   │   ├── adapters/
│   │   │   ├── behaviour.ex       # @callback definitions
│   │   │   ├── netcdf.ex          # NetCDF adapter
│   │   │   ├── geotiff.ex         # GeoTIFF adapter
│   │   │   └── shapefile.ex       # Shapefile adapter (pure Elixir)
│   │   ├── spatial/
│   │   │   ├── index.ex           # R-tree + bbox-grid
│   │   │   └── predicates.ex      # ST_Intersects, ST_Within, etc.
│   │   ├── types/
│   │   │   ├── schema.ex
│   │   │   ├── column.ex
│   │   │   ├── bbox.ex
│   │   │   └── result_set.ex
│   │   └── formatter/
│   │       ├── table.ex           # Pretty-print terminal table
│   │       ├── csv.ex
│   │       ├── json.ex
│   │       └── geojson.ex
├── test/
│   ├── adapters/
│   ├── query/
│   └── spatial/
└── priv/
    └── sample_data/               # Small .nc, .tif, .shp for tests
```

---

## 11. Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:nimble_parsec, "~> 1.4"},     # SQL lexer + parser
    {:geo, "~> 3.6"},               # Geometry types + WKT/WKB
    {:jason, "~> 1.4"},             # JSON output
    {:table_rex, "~> 4.0"},         # Terminal table formatter
    {:progress_bar, "~> 3.0"},      # Query progress indicator
    {:briefly, "~> 0.5"},           # Temp files for GDAL port calls
    # Dev / Test
    {:ex_doc, "~> 0.34", only: :dev},
    {:dialyxir, "~> 1.4", only: :dev},
    {:stream_data, "~> 1.1", only: :test},  # property-based testing
  ]
end
```

**External system dependencies:**
- `gdal-bin` — for GeoTIFF reading via Port (`gdalinfo`, `gdal_translate`)
- `netcdf-c` — for NetCDF NIF or Port
- Both available via `apt`, `brew`, `nix`

---

## 12. Build & Distribution

```bash
# Development
mix deps.get
mix compile
mix escript.build         # produces ./geoq binary

# Run
./geoq inspect data.nc
./geoq query "SELECT ..."

# Install globally
mix escript.install       # installs to ~/.mix/escripts/geoq
```

Single binary via `escript` — no Erlang/Elixir runtime required on target machine
(BEAM bundled in escript).

---

## 13. Error Handling Philosophy

All errors surface as structured tuples, never raw exceptions in user-facing paths.

```
geoq> SELECT avg(temeprature) FROM climate   ← typo
Error: Unknown column "temeprature" in "climate"
       Did you mean: "temperature"?

geoq> SELECT * FROM rainfall WHERE ST_Intersects(geom, nonexistent.geom)
Error: Table "nonexistent" is not registered.
       Run: geoq list  to see registered files.

geoq> SELECT * FROM /corrupted/file.nc
Error: Cannot read file: /corrupted/file.nc
       Reason: NetCDF header invalid (expected magic bytes 'CDF', got 'HDF')
```

---

## 14. Phase Plan

### Phase 1 — Skeleton (Target: working `inspect` + simple SELECT)
- [ ] Mix project setup, CLI command dispatch
- [ ] `geoq inspect` for .nc and .shp
- [ ] Schema Registry (GenServer + ETS)
- [ ] SQL Lexer + Parser (SELECT, FROM, WHERE with simple equality)
- [ ] NetCDF adapter: read variables as column stream
- [ ] Table formatter output
- [ ] `geoq query "SELECT temperature FROM climate LIMIT 10"`

### Phase 2 — Spatial Queries
- [ ] Shapefile adapter (pure Elixir binary parser)
- [ ] `geo` library integration for geometry types
- [ ] bbox() predicate pushed to adapter
- [ ] ST_Intersects predicate (naive, no index yet)
- [ ] R-tree index for vector files
- [ ] JOIN on spatial predicate

### Phase 3 — GeoTIFF + Aggregates
- [ ] GeoTIFF adapter via GDAL Port
- [ ] Tile-based chunked reads
- [ ] BEAM parallel Task reads per chunk
- [ ] GROUP BY + aggregate functions
- [ ] Progress bar during long queries

### Phase 4 — Polish
- [ ] REPL mode
- [ ] CSV / JSON / GeoJSON output formats
- [ ] `--format` flag
- [ ] Column suggestions on typo
- [ ] `geoq index build` pre-warming
- [ ] Temporal filter (BETWEEN, =) for NetCDF time dimension

---

## 15. Success Criteria (v1 Done When)

1. `geoq inspect era5_2024.nc` prints correct schema with zero configuration
2. `geoq query "SELECT avg(temperature) FROM climate WHERE bbox(-10,35,40,70)"` returns correct result
3. `geoq query "SELECT region_name, avg(value) FROM rainfall JOIN regions ON ST_Intersects(rainfall.geom, regions.geom) GROUP BY region_name"` executes correctly
4. Query on a 1GB .nc file completes in under 10 seconds on a standard laptop (with bbox filter)
5. Output pipeable to `jq`: `geoq query "..." --format json | jq '.[]'`

---

*Document owner: Rafsan | Status: Draft v0.1 | Next step: Phase 1 skeleton*
