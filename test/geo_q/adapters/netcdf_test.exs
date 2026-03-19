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

  test "read_columns reads 1D variable values with limit" do
    assert {:ok, rows} = Netcdf.read_columns(@netcdf_file, ["time"], limit: 3)

    assert length(rows) == 3
    assert Enum.all?(rows, fn row -> is_integer(row["time"]) end)
  end

  test "read_columns broadcasts scalar variables" do
    assert {:ok, rows} = Netcdf.read_columns(@netcdf_file, ["height", "time"], limit: 2)

    assert length(rows) == 2
    [first, second] = rows

    assert is_number(first["height"])
    assert first["height"] == second["height"]
    assert first["time"] != second["time"]
  end

  test "read_columns rejects unknown columns" do
    assert {:error, {:unknown_column, "missing"}} =
             Netcdf.read_columns(@netcdf_file, ["missing"], [])
  end

  test "read_columns rejects multi-dimensional variables for now" do
    assert {:error, {:unsupported_dimensions, "HWD_EU_health", ["time", "lat", "lon"]}} =
             Netcdf.read_columns(@netcdf_file, ["HWD_EU_health"], [])
  end
end
