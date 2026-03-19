defmodule GeoQ.Formatter.Table do
  @moduledoc """
  Table formatter with safe value truncation.

  This prevents very long geometry strings from flooding terminal output.
  """

  alias GeoQ.Types.ResultSet

  @max_value_length 140

  @spec format(ResultSet.t()) :: String.t()
  def format(%ResultSet{columns: columns, rows: rows}) do
    header = Enum.map_join(columns, " | ", &stringify/1)

    body =
      Enum.map_join(rows, "\n", fn row ->
        row
        |> List.wrap()
        |> Enum.map_join(" | ", &stringify/1)
      end)

    case body do
      "" -> header
      _ -> header <> "\n" <> body
    end
  end

  defp stringify(nil), do: ""

  defp stringify(value) do
    value
    |> to_string()
    |> truncate()
  end

  defp truncate(value) when is_binary(value) and byte_size(value) > @max_value_length do
    String.slice(value, 0, @max_value_length - 3) <> "..."
  end

  defp truncate(value), do: value
end
