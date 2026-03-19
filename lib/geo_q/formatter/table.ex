defmodule GeoQ.Formatter.Table do
  @moduledoc """
  Table formatter placeholder.
  """

  alias GeoQ.Types.ResultSet

  @spec format(ResultSet.t()) :: String.t()
  def format(%ResultSet{columns: columns, rows: rows}) do
    header = Enum.join(columns, " | ")
    body = Enum.map_join(rows, "\n", fn row -> Enum.join(List.wrap(row), " | ") end)

    case body do
      "" -> header
      _ -> header <> "\n" <> body
    end
  end
end
