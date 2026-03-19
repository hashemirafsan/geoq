defmodule GeoQ.Adapters.ShapefileContractTest do
  use ExUnit.Case, async: true

  alias GeoQ.AdapterContractCase
  alias GeoQ.Adapters.Shapefile

  @shapefile "data/gadm41_GRC_shp/gadm41_GRC_0.shp"

  test "shapefile adapter satisfies shared behavior contract" do
    schema = AdapterContractCase.assert_schema_success(Shapefile, @shapefile)

    assert schema.format == :shapefile

    rows =
      AdapterContractCase.assert_read_columns_success(
        Shapefile,
        @shapefile,
        ["COUNTRY", "GID_0"],
        limit: 1
      )

    assert rows == [%{"COUNTRY" => "Greece", "GID_0" => "GRC"}]

    AdapterContractCase.assert_read_columns_unknown(Shapefile, @shapefile, "MISSING")
    index = AdapterContractCase.assert_spatial_index_ok(Shapefile, @shapefile)
    assert index.index_type == :bbox_vector
    assert is_integer(index.feature_count)

    bbox = AdapterContractCase.assert_bbox_ok(Shapefile, @shapefile)
    assert bbox.min_x < bbox.max_x

    AdapterContractCase.assert_schema_missing_file(Shapefile, "data/missing.shp")
  end
end
