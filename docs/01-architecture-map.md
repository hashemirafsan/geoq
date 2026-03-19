# Architecture Map (Beginner-Friendly)

This page explains how GeoQ is organized today and where each future feature will live.

## 1) Big Picture Flow

When a user runs a command like:

```bash
geoq query "SELECT * FROM climate LIMIT 10"
```

the intended flow is:

1. `GeoQ.CLI` parses the command and options.
2. `GeoQ.Query.Lexer` tokenizes SQL.
3. `GeoQ.Query.Parser` builds an AST.
4. `GeoQ.Query.Planner` turns AST into an execution plan.
5. `GeoQ.Query.Executor` executes the plan.
6. `GeoQ.Formatter.*` turns result into table/csv/json/geojson output.

Right now, steps 1-4 are implemented for a minimal SQL subset, and step 5
executes a temporary metadata-backed result path while adapter row reads are pending.

## 2) Core Runtime Components

- `GeoQ.Application`: starts supervision tree.
- `GeoQ.Registry`: GenServer + ETS alias registry with JSON persistence (`~/.geoq/registry.json`).
- `GeoQ.CLI`: command dispatch for `register`, `unregister`, `list`, `inspect`, `query`, `repl`.

## 3) Data Model Modules

- `GeoQ.Types.Schema`
- `GeoQ.Types.Column`
- `GeoQ.Types.BBox`
- `GeoQ.Types.ResultSet`

These structs define the shared shape of metadata and query outputs.

## 4) Adapter Layer (Per File Format)

- `GeoQ.Adapters.Behaviour` defines the contract:
  - `schema/1`
  - `read_columns/3`
  - `spatial_index/1`
  - `bbox/1`
- `GeoQ.Adapters.Netcdf` (inspect schema implemented)
- `GeoQ.Adapters.GeoTiff`
- `GeoQ.Adapters.Shapefile` (inspect schema implemented)

Adapters are being implemented incrementally; query-path reads are still placeholders.

## 5) Spatial Layer

- `GeoQ.Spatial.Predicates`: `ST_Intersects`, `ST_Within`, etc. (planned)
- `GeoQ.Spatial.Index`: index build/cache logic (planned)

## 6) Output Layer

- `GeoQ.Formatter.Table`
- `GeoQ.Formatter.CSV`
- `GeoQ.Formatter.JSON`
- `GeoQ.Formatter.GeoJSON`

Only baseline placeholders exist now.

## 7) Why This Structure

- Keeps parsing/planning/execution separate for testability.
- Makes adapters pluggable per file type.
- Supports Docker-first and test-first development.
- Lets us evolve each stage with small, well-tested slices.

## 8) Next Implementation Slice

Next high-value slice is SQL query execution:

1. implement lexer tokens for v1 subset,
2. parse into AST,
3. plan projection/filter pushdown,
4. execute simple `SELECT ... FROM ... LIMIT ...` path.
