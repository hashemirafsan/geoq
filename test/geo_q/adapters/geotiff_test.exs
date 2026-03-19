defmodule GeoQ.Adapters.GeoTiffTest do
  use ExUnit.Case, async: true

  alias GeoQ.Adapters.GeoTiff

  @geotiff_file "data/fixture_small.tif"

  test "schema reads geotiff metadata and columns" do
    assert {:ok, schema} = GeoTiff.schema(@geotiff_file)

    assert schema.format == :geotiff
    assert schema.file_path == Path.expand(@geotiff_file)
    assert is_integer(schema.file_mtime)
    assert Enum.any?(schema.columns, fn column -> column.name == "band_1" end)
    assert Enum.any?(schema.columns, fn column -> column.name == "x" end)
    assert Enum.any?(schema.columns, fn column -> column.name == "y" end)
  end

  test "bbox returns extent from geotiff corners" do
    assert {:ok, bbox} = GeoTiff.bbox(@geotiff_file)
    assert bbox.min_x < bbox.max_x
    assert bbox.min_y < bbox.max_y
  end

  test "read_columns returns projected raster rows" do
    assert {:ok, rows} = GeoTiff.read_columns(@geotiff_file, ["x", "y", "band_1"], limit: 2)

    assert length(rows) == 2
    assert Enum.all?(rows, fn row -> is_number(row["x"]) and is_number(row["y"]) end)
  end

  test "read_columns rejects unknown column" do
    assert {:error, {:unknown_column, "missing"}} =
             GeoTiff.read_columns(@geotiff_file, ["missing"], [])
  end

  test "read_columns rejects unsupported band" do
    assert {:error, {:unsupported_band, "band_2"}} =
             GeoTiff.read_columns(@geotiff_file, ["band_2"], [])
  end

  test "spatial_index is not implemented for geotiff" do
    assert {:error, :not_implemented} = GeoTiff.spatial_index(@geotiff_file)
  end

  test "schema returns missing-file error" do
    assert {:error, {:file_not_found, expanded_path}} = GeoTiff.schema("data/missing.tif")
    assert expanded_path == Path.expand("data/missing.tif")
  end
end
