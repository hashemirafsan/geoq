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

  test "spatial_index returns bbox metadata hooks" do
    assert {:ok, index} = Shapefile.spatial_index(@shapefile)

    assert index.index_type == :bbox_vector
    assert index.layer_name == "gadm41_GRC_0"
    assert is_integer(index.feature_count)
    assert index.feature_count > 0
    assert index.bbox.min_x < index.bbox.max_x
    assert is_integer(index.file_mtime)
  end

  test "schema returns file-not-found error" do
    assert {:error, {:file_not_found, file_path}} = Shapefile.schema("data/missing.shp")
    assert file_path == Path.expand("data/missing.shp")
  end

  test "schema returns command error for non-shapefile content" do
    assert {:error, {:command_failed, message}} = Shapefile.schema("architecture.md")
    assert message =~ "FAILURE"
  end

  test "read_columns returns projected attribute rows" do
    assert {:ok, rows} = Shapefile.read_columns(@shapefile, ["COUNTRY", "GID_0"], limit: 1)

    assert rows == [%{"COUNTRY" => "Greece", "GID_0" => "GRC"}]
  end

  test "read_columns rejects unknown columns" do
    assert {:error, {:unknown_column, "MISSING"}} =
             Shapefile.read_columns(@shapefile, ["MISSING"], [])
  end

  test "read_columns supports geom as WKT" do
    assert {:ok, rows} = Shapefile.read_columns(@shapefile, ["geom"], limit: 1)
    assert length(rows) == 1
    assert Enum.at(rows, 0)["geom"] =~ "POLYGON"
  end

  test "read_columns supports mixed attribute and geom projection" do
    assert {:ok, rows} = Shapefile.read_columns(@shapefile, ["COUNTRY", "geom"], limit: 1)

    row = Enum.at(rows, 0)
    assert row["COUNTRY"] == "Greece"
    assert row["geom"] =~ "POLYGON"
  end

  test "read_columns applies zero limit" do
    assert {:ok, rows} = Shapefile.read_columns(@shapefile, ["COUNTRY"], limit: 0)
    assert rows == []
  end
end
