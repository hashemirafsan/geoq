defmodule GeoQ.Formatter.GeoJSON do
  @moduledoc """
  GeoJSON formatter placeholder.
  """

  alias GeoQ.Types.ResultSet

  @spec format(ResultSet.t()) :: {:error, :not_implemented}
  def format(%ResultSet{}) do
    {:error, :not_implemented}
  end
end
