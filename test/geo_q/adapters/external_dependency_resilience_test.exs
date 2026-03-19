defmodule GeoQ.Adapters.ExternalDependencyResilienceTest do
  use ExUnit.Case, async: false

  alias GeoQ.Adapters.GeoTiff
  alias GeoQ.Adapters.Netcdf
  alias GeoQ.Adapters.Shapefile

  @netcdf_file "data/HWD_EU_health_rcp85_mean_v1.0.nc"
  @shapefile "data/gadm41_GRC_shp/gadm41_GRC_0.shp"
  @geotiff_file "data/fixture_small.tif"

  setup do
    original_path = System.get_env("PATH")
    on_exit(fn -> restore_path(original_path) end)
    :ok
  end

  test "netcdf schema returns command_failed when ncdump is unavailable" do
    set_missing_commands()
    assert {:error, {:command_failed, message}} = Netcdf.schema(@netcdf_file)
    assert missing_command_message?(message)
  end

  test "shapefile schema returns command_failed when ogrinfo is unavailable" do
    set_missing_commands()
    assert {:error, {:command_failed, message}} = Shapefile.schema(@shapefile)
    assert missing_command_message?(message)
  end

  test "geotiff schema returns command_failed when gdalinfo is unavailable" do
    set_missing_commands()
    assert {:error, {:command_failed, message}} = GeoTiff.schema(@geotiff_file)
    assert missing_command_message?(message)
  end

  test "geotiff read_columns returns command_failed when gdal_translate is unavailable" do
    set_missing_commands()

    assert {:error, {:command_failed, message}} =
             GeoTiff.read_columns(@geotiff_file, ["x", "y", "band_1"], limit: 1)

    assert missing_command_message?(message)
  end

  defp set_missing_commands do
    System.put_env("PATH", "/geoq/no-such-bin")
  end

  defp restore_path(nil), do: System.delete_env("PATH")
  defp restore_path(path), do: System.put_env("PATH", path)

  defp missing_command_message?(message) when is_binary(message) do
    normalized = String.downcase(message)

    String.contains?(normalized, "enoent") or
      String.contains?(normalized, "not found") or
      String.contains?(normalized, "no such file")
  end
end
