defmodule GeoQ.Formatter.JSON do
  @moduledoc """
  JSON formatter for query result sets.
  """

  alias GeoQ.Types.ResultSet

  @spec format(ResultSet.t()) :: {:ok, String.t()} | {:error, term()}
  def format(%ResultSet{} = result_set) do
    payload = %{
      columns: result_set.columns,
      rows: Enum.map(result_set.rows, &row_to_map(&1, result_set.columns)),
      metadata: result_set.metadata
    }

    Jason.encode(payload, pretty: true)
  end

  defp row_to_map(row, _columns) when is_map(row), do: row

  defp row_to_map(row, columns) do
    row
    |> List.wrap()
    |> Enum.zip(columns)
    |> Enum.reduce(%{}, fn {value, column}, acc -> Map.put(acc, column, value) end)
  end
end
