defmodule GeoQ.Query.ExecutorTest do
  use ExUnit.Case, async: false

  alias GeoQ.Query.Executor
  alias GeoQ.Registry

  setup do
    storage_path = temp_storage_path()
    registry = start_supervised!({Registry, name: :executor_registry, storage_path: storage_path})

    :ok = Registry.register("mock_source", %{file_path: "data/example.mock"}, registry)

    :ok =
      Registry.register(
        "regions",
        %{file_path: "data/gadm41_GRC_shp/gadm41_GRC_0.shp"},
        registry
      )

    :ok =
      Registry.register(
        "climate",
        %{file_path: "data/HWD_EU_health_rcp85_mean_v1.0.nc"},
        registry
      )

    %{registry: registry}
  end

  test "executes select all query against non-netcdf source", %{registry: registry} do
    assert {:ok, result} = Executor.execute("SELECT * FROM mock_source LIMIT 1", registry)

    assert result.columns == ["alias", "file_path"]
    assert result.rows == [["mock_source", "data/example.mock"]]
  end

  test "applies adapter-backed netcdf projection", %{registry: registry} do
    assert {:ok, result} = Executor.execute("SELECT time FROM climate LIMIT 3", registry)

    assert result.columns == ["time"]
    assert length(result.rows) == 3
    assert Enum.all?(result.rows, fn [value] -> is_integer(value) end)
  end

  test "returns error for unknown projected column", %{registry: registry} do
    assert {:error, {:unknown_column, "temperature"}} =
             Executor.execute("SELECT temperature FROM climate", registry)
  end

  test "applies adapter-backed shapefile projection", %{registry: registry} do
    assert {:ok, result} = Executor.execute("SELECT COUNTRY FROM regions LIMIT 1", registry)

    assert result.columns == ["COUNTRY"]
    assert result.rows == [["Greece"]]
  end

  test "applies adapter-backed shapefile geom projection", %{registry: registry} do
    assert {:ok, result} = Executor.execute("SELECT geom FROM regions LIMIT 1", registry)

    assert result.columns == ["geom"]
    assert length(result.rows) == 1
    assert Enum.at(result.rows, 0) |> Enum.at(0) =~ "POLYGON"
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
