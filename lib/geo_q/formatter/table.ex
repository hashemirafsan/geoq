defmodule GeoQ.Formatter.Table do
  @moduledoc """
  Table formatter placeholder.
  """

  alias GeoQ.Types.ResultSet

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
  defp stringify(value), do: to_string(value)
end
