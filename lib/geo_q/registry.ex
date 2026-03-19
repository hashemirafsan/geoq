defmodule GeoQ.Registry do
  @moduledoc """
  Registry for mapping aliases to file metadata.

  Data is persisted to a JSON file so aliases survive process restarts.
  """

  use GenServer
  require Logger

  @type source_alias :: String.t()
  @type metadata :: map()
  @type server :: pid() | atom() | {:via, module(), term()}
  @type state :: %{table: :ets.tid(), storage_path: String.t()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    genserver_opts = opts |> Keyword.delete(:storage_path) |> Keyword.put_new(:name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, genserver_opts)
  end

  @spec register(source_alias(), metadata(), server()) ::
          :ok | {:error, :alias_exists} | {:error, {:persist_failed, term()}}
  def register(source_alias, metadata, server \\ __MODULE__)

  def register(source_alias, metadata, server)
      when is_binary(source_alias) and is_map(metadata) do
    GenServer.call(server, {:register, source_alias, metadata})
  end

  @spec unregister(source_alias(), server()) :: :ok | {:error, :not_found}
  def unregister(source_alias, server \\ __MODULE__)

  def unregister(source_alias, server) when is_binary(source_alias) do
    GenServer.call(server, {:unregister, source_alias})
  end

  @spec fetch(source_alias(), server()) :: {:ok, metadata()} | {:error, :not_found}
  def fetch(source_alias, server \\ __MODULE__)

  def fetch(source_alias, server) when is_binary(source_alias) do
    GenServer.call(server, {:fetch, source_alias})
  end

  @spec list(server()) :: [{source_alias(), metadata()}]
  def list(server \\ __MODULE__) do
    GenServer.call(server, :list)
  end

  @spec default_storage_path() :: String.t()
  def default_storage_path do
    home = System.get_env("HOME") || "."
    Path.join([home, ".geoq", "registry.json"])
  end

  @impl true
  def init(opts) do
    storage_path = Keyword.get(opts, :storage_path, default_storage_path())
    table = :ets.new(__MODULE__, [:set, :protected, read_concurrency: true])

    entries =
      case load_entries(storage_path) do
        {:ok, loaded_entries} ->
          loaded_entries

        {:error, reason} ->
          Logger.warning("Could not load registry from #{storage_path}: #{inspect(reason)}")
          %{}
      end

    seed_entries(table, entries)

    {:ok, %{table: table, storage_path: storage_path}}
  end

  @impl true
  def handle_call({:register, source_alias, metadata}, _from, state) do
    entries = entries_map(state.table)

    if Map.has_key?(entries, source_alias) do
      {:reply, {:error, :alias_exists}, state}
    else
      updated_entries = Map.put(entries, source_alias, metadata)

      case persist_entries(state.storage_path, updated_entries) do
        :ok ->
          true = :ets.insert(state.table, {source_alias, metadata})
          {:reply, :ok, state}

        {:error, reason} ->
          {:reply, {:error, {:persist_failed, reason}}, state}
      end
    end
  end

  def handle_call({:unregister, source_alias}, _from, state) do
    entries = entries_map(state.table)

    if Map.has_key?(entries, source_alias) do
      updated_entries = Map.delete(entries, source_alias)

      case persist_entries(state.storage_path, updated_entries) do
        :ok ->
          true = :ets.delete(state.table, source_alias)
          {:reply, :ok, state}

        {:error, reason} ->
          {:reply, {:error, {:persist_failed, reason}}, state}
      end
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:fetch, source_alias}, _from, state) do
    case :ets.lookup(state.table, source_alias) do
      [{^source_alias, metadata}] -> {:reply, {:ok, metadata}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:list, _from, state) do
    sorted_entries =
      state.table
      |> :ets.tab2list()
      |> Enum.sort_by(fn {source_alias, _metadata} -> source_alias end)

    {:reply, sorted_entries, state}
  end

  defp load_entries(storage_path) do
    if File.exists?(storage_path) do
      with {:ok, contents} <- File.read(storage_path),
           {:ok, decoded} <- Jason.decode(contents) do
        normalize_entries(decoded)
      end
    else
      {:ok, %{}}
    end
  end

  defp normalize_entries(decoded) when is_map(decoded) do
    Enum.reduce_while(decoded, {:ok, %{}}, fn
      {source_alias, metadata}, {:ok, acc} when is_binary(source_alias) and is_map(metadata) ->
        {:cont, {:ok, Map.put(acc, source_alias, normalize_metadata(metadata))}}

      _invalid_entry, _acc ->
        {:halt, {:error, :invalid_registry_shape}}
    end)
  end

  defp normalize_entries(_), do: {:error, :invalid_registry_shape}

  defp normalize_metadata(metadata) do
    Enum.reduce(metadata, %{}, fn
      {"file_path", value}, acc ->
        Map.put(acc, :file_path, value)

      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, normalize_value(value))

      {key, value}, acc when is_binary(key) ->
        Map.put(acc, key, normalize_value(value))
    end)
  end

  defp normalize_value(value) when is_map(value), do: normalize_metadata(value)
  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  defp normalize_value(value), do: value

  defp seed_entries(table, entries) do
    Enum.each(entries, fn {source_alias, metadata} ->
      true = :ets.insert(table, {source_alias, metadata})
    end)
  end

  defp entries_map(table) do
    table
    |> :ets.tab2list()
    |> Map.new(fn {source_alias, metadata} -> {source_alias, metadata} end)
  end

  defp persist_entries(storage_path, entries) do
    with :ok <- File.mkdir_p(Path.dirname(storage_path)),
         {:ok, encoded} <- Jason.encode(stringify_keys(entries), pretty: true) do
      File.write(storage_path, encoded <> "\n")
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} -> {key_to_string(key), stringify_keys(value)} end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp key_to_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_to_string(key), do: key
end
