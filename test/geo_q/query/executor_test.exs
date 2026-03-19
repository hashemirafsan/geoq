defmodule GeoQ.Query.ExecutorTest do
  use ExUnit.Case, async: false

  alias GeoQ.Query.Executor
  alias GeoQ.Registry

  setup do
    storage_path = temp_storage_path()
    registry = start_supervised!({Registry, name: :executor_registry, storage_path: storage_path})
    :ok = Registry.register("climate", %{file_path: "data/example.nc"}, registry)
    %{registry: registry}
  end

  test "executes select all query", %{registry: registry} do
    assert {:ok, result} = Executor.execute("SELECT * FROM climate LIMIT 1", registry)

    assert result.columns == ["alias", "file_path"]
    assert result.rows == [["climate", "data/example.nc"]]
  end

  test "applies projection and limit 0", %{registry: registry} do
    assert {:ok, result} = Executor.execute("SELECT file_path FROM climate LIMIT 0", registry)

    assert result.columns == ["file_path"]
    assert result.rows == []
  end

  test "returns error for unknown projected column", %{registry: registry} do
    assert {:error, {:unknown_column, "temperature"}} =
             Executor.execute("SELECT temperature FROM climate", registry)
  end

  test "returns error for unregistered source", %{registry: registry} do
    assert {:error, {:source_not_registered, "missing"}} =
             Executor.execute("SELECT * FROM missing", registry)
  end

  defp temp_storage_path do
    unique = System.unique_integer([:positive])
    Path.join(System.tmp_dir!(), "geoq-executor-#{unique}/registry.json")
  end
end
