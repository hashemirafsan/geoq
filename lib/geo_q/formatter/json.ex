defmodule GeoQ.Formatter.JSON do
  @moduledoc """
  JSON formatter placeholder.

  This currently returns `inspect/1` output to avoid adding dependencies until
  formatter behavior is fully defined.
  """

  alias GeoQ.Types.ResultSet

  @spec format(ResultSet.t()) :: String.t()
  def format(%ResultSet{} = result_set) do
    result_set
    |> Map.from_struct()
    |> inspect(pretty: true)
  end
end
