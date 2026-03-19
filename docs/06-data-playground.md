# Data Playground

Use this page to understand the sample files in `data/` and how to inspect them in Docker.

## What is in `data/`

- `*.tif` - GeoTIFF raster files
- `*.nc` - NetCDF climate/health data
- `gadm41_GRC_shp/` - Shapefile dataset for Greece boundaries
- `*.csv` - tabular climate projections

## Quick inspections in Docker

GeoTIFF metadata:

```bash
docker compose run --rm dev gdalinfo data/grc_t_60_2015_CN_100m_R2024B_v1.tif
```

NetCDF header/variables:

```bash
docker compose run --rm dev ncdump -h data/HWD_EU_health_rcp85_mean_v1.0.nc
```

Shapefile contents (via GDAL):

```bash
docker compose run --rm dev ogrinfo -so data/gadm41_GRC_shp/gadm41_GRC_0.shp gadm41_GRC_0
```

## Why this matters for GeoQ

- `inspect` command should surface schema-level metadata from these files.
- adapter tests should read small, deterministic slices from these files.
- query tests should validate bbox/spatial filters using the shapefile + raster/netcdf fixtures.
