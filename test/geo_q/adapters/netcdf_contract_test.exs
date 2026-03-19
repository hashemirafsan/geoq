defmodule GeoQ.Adapters.NetcdfContractTest do
  use ExUnit.Case, async: true

  alias GeoQ.AdapterContractCase
  alias GeoQ.Adapters.Netcdf

  @netcdf_file "data/HWD_EU_health_rcp85_mean_v1.0.nc"

  test "netcdf adapter satisfies shared behavior contract" do
    schema = AdapterContractCase.assert_schema_success(Netcdf, @netcdf_file)

    assert schema.format == :netcdf

    rows =
      AdapterContractCase.assert_read_columns_success(Netcdf, @netcdf_file, ["time"], limit: 2)

    assert length(rows) == 2

    AdapterContractCase.assert_read_columns_unknown(Netcdf, @netcdf_file, "missing")
    AdapterContractCase.assert_spatial_index_not_implemented(Netcdf, @netcdf_file)
    bbox = AdapterContractCase.assert_bbox_ok(Netcdf, @netcdf_file)
    assert bbox.min_x <= bbox.max_x
    assert bbox.min_y <= bbox.max_y
    AdapterContractCase.assert_schema_missing_file(Netcdf, "data/missing.nc")
  end
end
