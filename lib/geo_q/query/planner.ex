defmodule GeoQ.Query.Planner do
  @moduledoc """
  Minimal query planner.

  Responsibilities:
  - resolve source alias via `GeoQ.Registry`
  - carry projection and limit into execution plan
  """

  alias GeoQ.Registry

  @spec plan(map(), Registry.server()) :: {:ok, map()} | {:error, term()}
  def plan(ast, registry_server \\ Registry)

  def plan(%{from: source_alias, select: projection, limit: limit}, registry_server)
      when is_binary(source_alias) do
    case Registry.fetch(source_alias, registry_server) do
      {:ok, source_metadata} ->
        {:ok,
         %{
           source_alias: source_alias,
           source_metadata: source_metadata,
           projection: projection,
           limit: limit
         }}

      {:error, :not_found} ->
        {:error, {:source_not_registered, source_alias}}
    end
  end

  def plan(_ast, _registry_server), do: {:error, :invalid_ast}
end
