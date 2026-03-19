defmodule GeoQ.CLITest do
  use ExUnit.Case, async: false

  alias GeoQ.CLI
  alias GeoQ.Registry

  @netcdf_file "data/HWD_EU_health_rcp85_mean_v1.0.nc"
  @shapefile "data/gadm41_GRC_shp/gadm41_GRC_0.shp"
  @csv_file "data/mpi_rca4smhi_1980_2004.csv"

  test "unknown command returns error" do
    assert {:error, :unknown_command} = CLI.dispatch(["unknown"])
  end

  test "register rejects missing file path" do
    assert {:error, {:file_not_found, _expanded_path}} =
             CLI.dispatch(["register", "data/not-found.nc", "--alias", "bad_alias"])
  end

  test "register rejects duplicate alias" do
    alias_name = "alias_#{System.unique_integer([:positive])}"

    assert {:ok, _output} = CLI.dispatch(["register", @netcdf_file, "--alias", alias_name])

    assert {:error, :alias_exists} =
             CLI.dispatch(["register", @netcdf_file, "--alias", alias_name])

    assert :ok = Registry.unregister(alias_name)
  end

  test "inspect command supports netcdf table output" do
    assert {:ok, output} = CLI.dispatch(["inspect", @netcdf_file])
    assert output =~ "Format: netcdf"
    assert output =~ "HWD_EU_health"
  end

  test "inspect command supports netcdf json output" do
    assert {:ok, output} = CLI.dispatch(["inspect", "--format", "json", @netcdf_file])

    decoded = Jason.decode!(output)
    assert decoded["format"] == "netcdf"
    assert decoded["file_path"] == Path.expand(@netcdf_file)
    assert Enum.any?(decoded["columns"], fn column -> column["name"] == "HWD_EU_health" end)
  end

  test "inspect command supports shapefile table output" do
    assert {:ok, output} = CLI.dispatch(["inspect", @shapefile])
    assert output =~ "Format: shapefile"
    assert output =~ "geom"
    assert output =~ "COUNTRY"
  end

  test "inspect command supports shapefile json output" do
    assert {:ok, output} = CLI.dispatch(["inspect", "--format", "json", @shapefile])

    decoded = Jason.decode!(output)
    assert decoded["format"] == "shapefile"
    assert decoded["crs"] == "EPSG:4326"
    assert decoded["bbox"]["min_x"] < decoded["bbox"]["max_x"]
    assert Enum.any?(decoded["columns"], fn column -> column["name"] == "COUNTRY" end)
  end

  test "inspect command rejects unsupported output format" do
    assert {:error, {:unsupported_output_format, "yaml"}} =
             CLI.dispatch(["inspect", "--format", "yaml", @netcdf_file])
  end

  test "inspect command rejects unsupported source format" do
    assert {:error, {:unsupported_source_format, ".csv"}} = CLI.dispatch(["inspect", @csv_file])
  end

  test "inspect command requires a path" do
    assert {:error, :invalid_inspect_args} = CLI.dispatch(["inspect"])
  end

  test "query command returns table output for registered alias" do
    alias_name = "query_alias_#{System.unique_integer([:positive])}"
    assert {:ok, _} = CLI.dispatch(["register", @netcdf_file, "--alias", alias_name])

    assert {:ok, output} = CLI.dispatch(["query", "SELECT * FROM #{alias_name} LIMIT 1"])
    assert output =~ "alias | file_path"
    assert output =~ alias_name

    assert :ok = Registry.unregister(alias_name)
  end

  test "query command supports csv format" do
    alias_name = "query_csv_#{System.unique_integer([:positive])}"
    assert {:ok, _} = CLI.dispatch(["register", @netcdf_file, "--alias", alias_name])

    assert {:ok, output} =
             CLI.dispatch([
               "query",
               "--format",
               "csv",
               "SELECT time FROM #{alias_name} LIMIT 1"
             ])

    assert output =~ "time"

    assert :ok = Registry.unregister(alias_name)
  end

  test "query command supports adapter-backed netcdf projection" do
    alias_name = "query_time_#{System.unique_integer([:positive])}"
    assert {:ok, _} = CLI.dispatch(["register", @netcdf_file, "--alias", alias_name])

    assert {:ok, output} = CLI.dispatch(["query", "SELECT time FROM #{alias_name} LIMIT 2"])
    assert output =~ "time"

    assert :ok = Registry.unregister(alias_name)
  end

  test "query command validates args" do
    assert {:error, :invalid_query_args} = CLI.dispatch(["query"])
  end
end
