#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEOQ_BIN="${GEOQ_BIN:-geoq}"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "Assertion failed: expected output to contain: $needle" >&2
    exit 1
  fi
}

if ! command -v "$GEOQ_BIN" >/dev/null 2>&1; then
  echo "GeoQ binary not found: $GEOQ_BIN" >&2
  exit 1
fi

export HOME="$(mktemp -d)"
trap 'rm -rf "$HOME"' EXIT

bash "${ROOT_DIR}/scripts/prepare_test_fixtures.sh"

version_output="$($GEOQ_BIN --version)"
if [[ ! "$version_output" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "Unexpected version output: $version_output" >&2
  exit 1
fi

doctor_output="$($GEOQ_BIN doctor)"
assert_contains "$doctor_output" "Doctor check passed"

inspect_nc="$($GEOQ_BIN inspect "${ROOT_DIR}/data/HWD_EU_health_rcp85_mean_v1.0.nc")"
assert_contains "$inspect_nc" "Format: netcdf"

inspect_shp="$($GEOQ_BIN inspect "${ROOT_DIR}/data/gadm41_GRC_shp/gadm41_GRC_0.shp")"
assert_contains "$inspect_shp" "Format: shapefile"

inspect_tif="$($GEOQ_BIN inspect "${ROOT_DIR}/data/fixture_small.tif")"
assert_contains "$inspect_tif" "Format: geotiff"

$GEOQ_BIN register "${ROOT_DIR}/data/HWD_EU_health_rcp85_mean_v1.0.nc" --alias climate
$GEOQ_BIN register "${ROOT_DIR}/data/gadm41_GRC_shp/gadm41_GRC_0.shp" --alias regions
$GEOQ_BIN register "${ROOT_DIR}/data/fixture_small.tif" --alias raster

list_output="$($GEOQ_BIN list)"
assert_contains "$list_output" "climate"
assert_contains "$list_output" "regions"
assert_contains "$list_output" "raster"

query_nc="$($GEOQ_BIN query "SELECT time FROM climate LIMIT 2")"
assert_contains "$query_nc" "time"

query_shp="$($GEOQ_BIN query "SELECT COUNTRY FROM regions LIMIT 1")"
assert_contains "$query_shp" "COUNTRY"

query_tif="$($GEOQ_BIN query "SELECT band_1 FROM raster LIMIT 1")"
assert_contains "$query_tif" "band_1"

if $GEOQ_BIN register "${ROOT_DIR}/data/HWD_EU_health_rcp85_mean_v1.0.nc" --alias climate >/dev/null 2>&1; then
  echo "Expected duplicate alias register to fail" >&2
  exit 1
fi

if $GEOQ_BIN query "SELECT unknown FROM climate" >/dev/null 2>&1; then
  echo "Expected unknown column query to fail" >&2
  exit 1
fi

$GEOQ_BIN unregister climate
$GEOQ_BIN unregister regions
$GEOQ_BIN unregister raster

echo "macOS user journey smoke passed"
