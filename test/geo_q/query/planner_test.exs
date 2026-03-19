defmodule GeoQ.Query.PlannerTest do
  use ExUnit.Case, async: false

  alias GeoQ.Query.Planner
  alias GeoQ.Registry

  setup do
    storage_path = temp_storage_path()
    registry = start_supervised!({Registry, name: :planner_registry, storage_path: storage_path})
    %{registry: registry}
  end

  test "builds plan when source alias exists", %{registry: registry} do
    :ok = Registry.register("climate", %{file_path: "data/example.nc"}, registry)

    ast = %{select: :all, from: "climate", limit: 1}
    assert {:ok, plan} = Planner.plan(ast, registry)

    assert plan.source_alias == "climate"
    assert plan.projection == :all
    assert plan.limit == 1
    assert plan.source_metadata == %{file_path: "data/example.nc"}
  end

  test "returns error when source alias is missing", %{registry: registry} do
    ast = %{select: :all, from: "unknown", limit: nil}
    assert {:error, {:source_not_registered, "unknown"}} = Planner.plan(ast, registry)
  end

  defp temp_storage_path do
    unique = System.unique_integer([:positive])
    Path.join(System.tmp_dir!(), "geoq-planner-#{unique}/registry.json")
  end
end
