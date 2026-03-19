defmodule GeoQ.Query.PlannerTest do
  use ExUnit.Case, async: false

  alias GeoQ.Query.Planner
  alias GeoQ.Registry
  alias GeoQ.TestSupport

  setup do
    storage_path = TestSupport.temp_storage_path("geoq-planner")

    registry =
      start_supervised!(
        {Registry,
         name: TestSupport.unique_registry_name("planner_registry"), storage_path: storage_path}
      )

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
end
