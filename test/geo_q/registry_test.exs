defmodule GeoQ.RegistryTest do
  use ExUnit.Case, async: false

  alias GeoQ.Registry
  alias GeoQ.TestSupport

  setup do
    storage_path = TestSupport.temp_storage_path("geoq-registry")

    registry =
      start_supervised!(
        {Registry,
         name: TestSupport.unique_registry_name("registry_test"), storage_path: storage_path}
      )

    %{registry: registry, storage_path: storage_path}
  end

  test "register and fetch alias", %{registry: registry} do
    assert :ok = Registry.register("climate", %{file_path: "data/example.nc"}, registry)
    assert {:ok, %{file_path: "data/example.nc"}} = Registry.fetch("climate", registry)
  end

  test "registry stores entries in ETS table", %{registry: registry} do
    assert :ok = Registry.register("climate", %{file_path: "data/example.nc"}, registry)

    state = :sys.get_state(registry)
    assert is_reference(state.table)
    assert [{"climate", %{file_path: "data/example.nc"}}] = :ets.lookup(state.table, "climate")
  end

  test "unregister existing alias", %{registry: registry} do
    assert :ok = Registry.register("regions", %{file_path: "data/example.shp"}, registry)
    assert :ok = Registry.unregister("regions", registry)
    assert {:error, :not_found} = Registry.fetch("regions", registry)
  end

  test "register persists entries to registry file", %{
    registry: registry,
    storage_path: storage_path
  } do
    assert :ok = Registry.register("climate", %{file_path: "data/example.nc"}, registry)

    assert {:ok, contents} = File.read(storage_path)
    decoded = Jason.decode!(contents)

    assert decoded["climate"]["file_path"] == "data/example.nc"
  end

  test "register rejects duplicate aliases", %{registry: registry, storage_path: storage_path} do
    assert :ok = Registry.register("climate", %{file_path: "data/example.nc"}, registry)

    assert {:error, :alias_exists} =
             Registry.register("climate", %{file_path: "data/other.nc"}, registry)

    assert {:ok, %{file_path: "data/example.nc"}} = Registry.fetch("climate", registry)

    assert {:ok, contents} = File.read(storage_path)
    decoded = Jason.decode!(contents)
    assert decoded["climate"]["file_path"] == "data/example.nc"
  end

  test "entries survive registry restart", %{storage_path: storage_path} do
    {:ok, first_registry} =
      Registry.start_link(
        name: TestSupport.unique_registry_name("registry_restart_a"),
        storage_path: storage_path
      )

    assert :ok = Registry.register("climate", %{file_path: "data/example.nc"}, first_registry)
    assert :ok = GenServer.stop(first_registry)

    {:ok, second_registry} =
      Registry.start_link(
        name: TestSupport.unique_registry_name("registry_restart_b"),
        storage_path: storage_path
      )

    on_exit(fn -> if Process.alive?(second_registry), do: GenServer.stop(second_registry) end)

    assert {:ok, %{file_path: "data/example.nc"}} = Registry.fetch("climate", second_registry)
  end

  test "corrupted registry file falls back to empty entries", %{storage_path: storage_path} do
    assert :ok = File.mkdir_p(Path.dirname(storage_path))
    assert :ok = File.write(storage_path, "{ not json")

    {:ok, registry} =
      Registry.start_link(
        name: TestSupport.unique_registry_name("registry_corrupted"),
        storage_path: storage_path
      )

    on_exit(fn -> if Process.alive?(registry), do: GenServer.stop(registry) end)

    assert [] = Registry.list(registry)
  end
end
