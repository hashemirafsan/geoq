defmodule GeoQ.Adapters.NetcdfTest do
  use ExUnit.Case, async: true

  alias GeoQ.Adapters.Netcdf

  @netcdf_file "data/HWD_EU_health_rcp85_mean_v1.0.nc"

  test "schema reads metadata and variables from netcdf file" do
    assert {:ok, schema} = Netcdf.schema(@netcdf_file)

    assert schema.format == :netcdf
    assert schema.file_path == Path.expand(@netcdf_file)
    assert schema.source_alias == "HWD_EU_health_rcp85_mean_v1.0"
    assert is_integer(schema.file_mtime)

    assert Enum.any?(schema.columns, fn column ->
             column.name == "HWD_EU_health" and column.type == :float32 and
               column.unit == "day" and column.dims == ["time", "lat", "lon"]
           end)
  end

  test "schema returns file-not-found error" do
    assert {:error, {:file_not_found, file_path}} = Netcdf.schema("data/missing.nc")
    assert file_path == Path.expand("data/missing.nc")
  end

  test "schema returns command error for non-netcdf content" do
    assert {:error, {:command_failed, message}} = Netcdf.schema("architecture.md")
    assert message =~ "Unknown file format"
  end
end
