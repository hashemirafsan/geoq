defmodule GeoQ.Query.Parser do
  @moduledoc """
  SQL parser placeholder.
  """

  alias GeoQ.Query.Lexer

  @spec parse(String.t()) :: {:ok, map()} | {:error, term()}
  def parse(sql) when is_binary(sql) do
    with {:ok, _tokens} <- Lexer.tokenize(sql) do
      {:error, :not_implemented}
    end
  end
end
