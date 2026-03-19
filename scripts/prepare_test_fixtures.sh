#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"
SHAPE_DIR="${DATA_DIR}/gadm41_GRC_shp"
NETCDF_FILE="${DATA_DIR}/HWD_EU_health_rcp85_mean_v1.0.nc"
SHAPE_FILE="${SHAPE_DIR}/gadm41_GRC_0.shp"
CSV_FILE="${DATA_DIR}/mpi_rca4smhi_1980_2004.csv"
GEOTIFF_FILE="${DATA_DIR}/fixture_small.tif"

mkdir -p "${DATA_DIR}" "${SHAPE_DIR}"

if [[ ! -f "${NETCDF_FILE}" ]]; then
  cat >"${DATA_DIR}/fixture.cdl" <<'EOF'
netcdf geoq_fixture {
dimensions:
  time = 3 ;
  lat = 2 ;
  lon = 2 ;
variables:
  int time(time) ;
    time:units = "days since 2000-01-01" ;
  float lat(lat) ;
    lat:units = "degrees_north" ;
  float lon(lon) ;
    lon:units = "degrees_east" ;
  int height ;
    height:units = "m" ;
  float HWD_EU_health(time, lat, lon) ;
    HWD_EU_health:units = "day" ;
data:
  time = 0, 365, 730 ;
  lat = 37, 39 ;
  lon = 23, 25 ;
  height = 2 ;
  HWD_EU_health = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 ;
}
EOF

  ncgen -o "${NETCDF_FILE}" "${DATA_DIR}/fixture.cdl"
  rm -f "${DATA_DIR}/fixture.cdl"
fi

if [[ ! -f "${SHAPE_FILE}" ]]; then
  cat >"${DATA_DIR}/fixture.geojson" <<'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "COUNTRY": "Greece",
        "GID_0": "GRC"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [23.0, 38.0],
            [24.0, 38.0],
            [24.0, 39.0],
            [23.0, 39.0],
            [23.0, 38.0]
          ]
        ]
      }
    }
  ]
}
EOF

  ogr2ogr -f "ESRI Shapefile" "${SHAPE_FILE}" "${DATA_DIR}/fixture.geojson"
  rm -f "${DATA_DIR}/fixture.geojson"
fi

if [[ ! -f "${CSV_FILE}" ]]; then
  cat >"${CSV_FILE}" <<'EOF'
year,value
1980,1
EOF
fi

if [[ ! -f "${GEOTIFF_FILE}" ]]; then
  cat >"${DATA_DIR}/fixture_raster.geojson" <<'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"value": 5},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [23.0, 38.0],
            [24.0, 38.0],
            [24.0, 39.0],
            [23.0, 39.0],
            [23.0, 38.0]
          ]
        ]
      }
    }
  ]
}
EOF

  gdal_rasterize \
    -burn 5 \
    -a_nodata -99999 \
    -ot Float32 \
    -tr 0.5 0.5 \
    -te 23 38 24 39 \
    -of GTiff \
    "${DATA_DIR}/fixture_raster.geojson" \
    "${GEOTIFF_FILE}"

  rm -f "${DATA_DIR}/fixture_raster.geojson"
fi

echo "Test fixtures are available in ${DATA_DIR}"
