defmodule GeoQ.Adapters.ShapefileTest do
  use ExUnit.Case, async: true

  alias GeoQ.Adapters.Shapefile

  @shapefile "data/gadm41_GRC_shp/gadm41_GRC_0.shp"

  test "schema reads metadata and columns from shapefile" do
    assert {:ok, schema} = Shapefile.schema(@shapefile)

    assert schema.format == :shapefile
    assert schema.file_path == Path.expand(@shapefile)
    assert schema.source_alias == "gadm41_GRC_0"
    assert schema.crs == "EPSG:4326"
    assert is_integer(schema.file_mtime)

    assert schema.bbox.min_x < schema.bbox.max_x
    assert schema.bbox.min_y < schema.bbox.max_y

    assert Enum.any?(schema.columns, fn column ->
             column.name == "geom" and column.type == :polygon
           end)

    assert Enum.any?(schema.columns, fn column ->
             column.name == "COUNTRY" and column.type == :string
           end)
  end

  test "bbox returns extent from shapefile" do
    assert {:ok, bbox} = Shapefile.bbox(@shapefile)
    assert bbox.min_x < bbox.max_x
    assert bbox.min_y < bbox.max_y
  end

  test "schema returns file-not-found error" do
    assert {:error, {:file_not_found, file_path}} = Shapefile.schema("data/missing.shp")
    assert file_path == Path.expand("data/missing.shp")
  end

  test "schema returns command error for non-shapefile content" do
    assert {:error, {:command_failed, message}} = Shapefile.schema("architecture.md")
    assert message =~ "FAILURE"
  end
end
