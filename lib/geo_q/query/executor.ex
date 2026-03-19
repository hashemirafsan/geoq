defmodule GeoQ.Query.Executor do
  @moduledoc """
  Minimal query execution pipeline.

  For now execution reads from registry metadata only (single synthetic row per
  registered source) while file adapters for row-level reads are implemented.
  """

  alias GeoQ.Adapters.Netcdf
  alias GeoQ.Adapters.Shapefile
  alias GeoQ.Query.Parser
  alias GeoQ.Query.Planner
  alias GeoQ.Registry
  alias GeoQ.Types.ResultSet

  @spec execute(String.t(), Registry.server()) :: {:ok, ResultSet.t()} | {:error, term()}
  def execute(sql, registry_server \\ Registry)

  def execute(sql, registry_server) when is_binary(sql) do
    with {:ok, ast} <- Parser.parse(sql),
         {:ok, plan} <- Planner.plan(ast, registry_server) do
      execute_plan(plan)
    end
  end

  defp execute_plan(%{source_metadata: source_metadata} = plan) do
    source_path = Map.get(source_metadata, :file_path) || Map.get(source_metadata, "file_path")

    case String.downcase(Path.extname(source_path || "")) do
      ".nc" -> execute_netcdf_query(plan, source_path)
      ".shp" -> execute_shapefile_query(plan, source_path)
      _ -> execute_metadata_query(plan)
    end
  end

  defp execute_netcdf_query(%{projection: :all} = plan, _source_path) do
    execute_metadata_query(plan)
  end

  defp execute_netcdf_query(
         %{projection: projection, limit: limit, source_alias: source_alias},
         source_path
       )
       when is_list(projection) do
    filters = if is_nil(limit), do: [], else: [limit: limit]

    with {:ok, rows} <- Netcdf.read_columns(source_path, projection, filters) do
      result_rows = Enum.map(rows, fn row -> Enum.map(projection, &Map.get(row, &1)) end)

      {:ok,
       %ResultSet{
         columns: projection,
         rows: result_rows,
         metadata: %{source_alias: source_alias}
       }}
    end
  end

  defp execute_netcdf_query(_plan, _source_path), do: {:error, :invalid_projection}

  defp execute_shapefile_query(%{projection: :all} = plan, _source_path) do
    execute_metadata_query(plan)
  end

  defp execute_shapefile_query(
         %{projection: projection, limit: limit, source_alias: source_alias},
         source_path
       )
       when is_list(projection) do
    filters = if is_nil(limit), do: [], else: [limit: limit]

    with {:ok, rows} <- Shapefile.read_columns(source_path, projection, filters) do
      result_rows = Enum.map(rows, fn row -> Enum.map(projection, &Map.get(row, &1)) end)

      {:ok,
       %ResultSet{
         columns: projection,
         rows: result_rows,
         metadata: %{source_alias: source_alias}
       }}
    end
  end

  defp execute_shapefile_query(_plan, _source_path), do: {:error, :invalid_projection}

  defp execute_metadata_query(
         %{source_alias: source_alias, source_metadata: source_metadata} = plan
       ) do
    base_row = %{
      "alias" => source_alias,
      "file_path" => Map.get(source_metadata, :file_path) || Map.get(source_metadata, "file_path")
    }

    with {:ok, columns} <- resolve_columns(plan.projection),
         {:ok, row} <- project_row(base_row, columns) do
      rows = apply_limit([row], plan.limit)
      {:ok, %ResultSet{columns: columns, rows: rows, metadata: %{source_alias: source_alias}}}
    end
  end

  defp resolve_columns(:all), do: {:ok, ["alias", "file_path"]}
  defp resolve_columns(columns) when is_list(columns), do: {:ok, columns}
  defp resolve_columns(_), do: {:error, :invalid_projection}

  defp project_row(base_row, columns) do
    Enum.reduce_while(columns, {:ok, []}, fn column, {:ok, acc} ->
      case Map.fetch(base_row, column) do
        {:ok, value} -> {:cont, {:ok, acc ++ [value]}}
        :error -> {:halt, {:error, {:unknown_column, column}}}
      end
    end)
  end

  defp apply_limit(rows, nil), do: rows
  defp apply_limit(_rows, limit) when limit <= 0, do: []
  defp apply_limit(rows, limit), do: Enum.take(rows, limit)
end
