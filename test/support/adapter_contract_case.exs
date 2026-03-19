defmodule GeoQ.AdapterContractCase do
  @moduledoc false

  import ExUnit.Assertions

  alias GeoQ.Types.BBox
  alias GeoQ.Types.Schema

  @spec assert_schema_success(module(), String.t()) :: Schema.t()
  def assert_schema_success(adapter, file_path) do
    assert {:ok, %Schema{} = schema} = adapter.schema(file_path)
    schema
  end

  @spec assert_schema_missing_file(module(), String.t()) :: :ok
  def assert_schema_missing_file(adapter, missing_file_path) do
    assert {:error, {:file_not_found, _expanded}} = adapter.schema(missing_file_path)
    :ok
  end

  @spec assert_read_columns_success(module(), String.t(), [String.t()], keyword()) :: [map()]
  def assert_read_columns_success(adapter, file_path, columns, filters \\ []) do
    assert {:ok, rows} = adapter.read_columns(file_path, columns, filters)
    assert is_list(rows)
    rows
  end

  @spec assert_read_columns_unknown(module(), String.t(), String.t()) :: :ok
  def assert_read_columns_unknown(adapter, file_path, unknown_column) do
    assert {:error, {:unknown_column, ^unknown_column}} =
             adapter.read_columns(file_path, [unknown_column], [])

    :ok
  end

  @spec assert_spatial_index_not_implemented(module(), String.t()) :: :ok
  def assert_spatial_index_not_implemented(adapter, file_path) do
    assert {:error, :not_implemented} = adapter.spatial_index(file_path)
    :ok
  end

  @spec assert_spatial_index_ok(module(), String.t()) :: map()
  def assert_spatial_index_ok(adapter, file_path) do
    assert {:ok, index} = adapter.spatial_index(file_path)
    assert is_map(index)
    index
  end

  @spec assert_bbox_ok(module(), String.t()) :: BBox.t()
  def assert_bbox_ok(adapter, file_path) do
    assert {:ok, %BBox{} = bbox} = adapter.bbox(file_path)
    bbox
  end

  @spec assert_bbox_not_implemented(module(), String.t()) :: :ok
  def assert_bbox_not_implemented(adapter, file_path) do
    assert {:error, :not_implemented} = adapter.bbox(file_path)
    :ok
  end
end
