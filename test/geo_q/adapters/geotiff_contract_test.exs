defmodule GeoQ.Adapters.GeoTiffContractTest do
  use ExUnit.Case, async: true

  alias GeoQ.AdapterContractCase
  alias GeoQ.Adapters.GeoTiff

  @geotiff_file "data/fixture_small.tif"

  test "geotiff adapter satisfies shared behavior contract" do
    schema = AdapterContractCase.assert_schema_success(GeoTiff, @geotiff_file)
    assert schema.format == :geotiff

    rows =
      AdapterContractCase.assert_read_columns_success(
        GeoTiff,
        @geotiff_file,
        ["x", "y", "band_1"],
        limit: 1
      )

    assert length(rows) == 1

    AdapterContractCase.assert_read_columns_unknown(GeoTiff, @geotiff_file, "missing")
    AdapterContractCase.assert_spatial_index_not_implemented(GeoTiff, @geotiff_file)

    bbox = AdapterContractCase.assert_bbox_ok(GeoTiff, @geotiff_file)
    assert bbox.min_x < bbox.max_x

    AdapterContractCase.assert_schema_missing_file(GeoTiff, "data/missing.tif")
  end
end
