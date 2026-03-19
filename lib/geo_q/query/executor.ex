defmodule GeoQ.Query.Executor do
  @moduledoc """
  Query execution placeholder.
  """

  alias GeoQ.Query.Parser
  alias GeoQ.Query.Planner
  alias GeoQ.Types.ResultSet

  @spec execute(String.t()) :: {:ok, ResultSet.t()} | {:error, term()}
  def execute(sql) when is_binary(sql) do
    with {:ok, ast} <- Parser.parse(sql),
         {:ok, _plan} <- Planner.plan(ast) do
      {:ok, %ResultSet{columns: [], rows: [], metadata: %{}}}
    end
  end
end
