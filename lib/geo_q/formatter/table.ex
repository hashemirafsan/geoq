defmodule GeoQ.Formatter.Table do
  @moduledoc """
  Table formatter with safe value truncation.

  This prevents very long geometry strings from flooding terminal output.
  """

  alias GeoQ.Types.ResultSet

  @default_max_value_length 140

  @spec format(ResultSet.t(), keyword()) :: String.t()
  def format(%ResultSet{columns: columns, rows: rows}, opts \\ []) do
    truncate? = Keyword.get(opts, :truncate, true)
    max_cell_length = Keyword.get(opts, :max_cell_length, @default_max_value_length)

    header = Enum.map_join(columns, " | ", &stringify(&1, truncate?, max_cell_length))

    body =
      Enum.map_join(rows, "\n", fn row ->
        row
        |> List.wrap()
        |> Enum.map_join(" | ", &stringify(&1, truncate?, max_cell_length))
      end)

    case body do
      "" -> header
      _ -> header <> "\n" <> body
    end
  end

  defp stringify(nil, _truncate?, _max_cell_length), do: ""

  defp stringify(value, truncate?, max_cell_length) do
    value
    |> to_string()
    |> truncate(truncate?, max_cell_length)
  end

  defp truncate(value, false, _max_cell_length), do: value

  defp truncate(value, true, max_cell_length)
       when is_binary(value) and byte_size(value) > max_cell_length do
    String.slice(value, 0, max_cell_length - 3) <> "..."
  end

  defp truncate(value, _truncate?, _max_cell_length), do: value
end
