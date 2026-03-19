defmodule GeoQ.Formatter.CSV do
  @moduledoc """
  CSV formatter placeholder.
  """

  alias GeoQ.Types.ResultSet

  @spec format(ResultSet.t()) :: String.t()
  def format(%ResultSet{columns: columns, rows: rows}) do
    header = Enum.join(columns, ",")

    body =
      Enum.map_join(rows, "\n", fn row -> Enum.map_join(List.wrap(row), ",", &to_string/1) end)

    case body do
      "" -> header
      _ -> header <> "\n" <> body
    end
  end
end
