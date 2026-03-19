defmodule GeoQ.Query.Lexer do
  @moduledoc """
  SQL lexer placeholder.
  """

  @spec tokenize(String.t()) :: {:ok, [term()]} | {:error, :not_implemented}
  def tokenize(_sql) do
    {:error, :not_implemented}
  end
end
