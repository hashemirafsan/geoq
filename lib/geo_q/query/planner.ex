defmodule GeoQ.Query.Planner do
  @moduledoc """
  Query planner placeholder.
  """

  @spec plan(map()) :: {:ok, map()} | {:error, :not_implemented}
  def plan(_ast) do
    {:error, :not_implemented}
  end
end
