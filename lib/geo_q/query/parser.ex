defmodule GeoQ.Query.Parser do
  @moduledoc """
  Parser for the minimal GeoQ SQL subset.

  Supported grammar:

      SELECT <projection> FROM <source_alias> [LIMIT <n>]

  where `<projection>` is either `*` or comma-separated identifiers.
  """

  alias GeoQ.Query.Lexer

  @type ast :: %{
          select: :all | [String.t()],
          from: String.t(),
          limit: non_neg_integer() | nil
        }

  @spec parse(String.t()) :: {:ok, ast()} | {:error, term()}
  def parse(sql) when is_binary(sql) do
    with {:ok, tokens} <- Lexer.tokenize(sql),
         {:ok, ast, []} <- parse_query(tokens) do
      {:ok, ast}
    else
      {:ok, _ast, remaining} -> {:error, {:unexpected_tokens, remaining}}
      {:error, _reason} = error -> error
    end
  end

  defp parse_query([{:keyword, :select} | rest]) do
    with {:ok, projection, after_projection} <- parse_projection(rest),
         {:ok, source_alias, after_from} <- parse_from_clause(after_projection),
         {:ok, limit, remaining} <- parse_optional_limit(after_from) do
      {:ok, %{select: projection, from: source_alias, limit: limit}, remaining}
    end
  end

  defp parse_query(_tokens), do: {:error, {:expected, :select}}

  defp parse_projection([:star | rest]), do: {:ok, :all, rest}

  defp parse_projection(tokens) do
    parse_identifier_list(tokens, [])
  end

  defp parse_identifier_list([{:identifier, column} | rest], acc) do
    case rest do
      [:comma | tail] -> parse_identifier_list(tail, [column | acc])
      _ -> {:ok, Enum.reverse([column | acc]), rest}
    end
  end

  defp parse_identifier_list(_tokens, _acc), do: {:error, {:expected, :projection}}

  defp parse_from_clause([{:keyword, :from}, {:identifier, source_alias} | rest]) do
    {:ok, source_alias, rest}
  end

  defp parse_from_clause(_tokens), do: {:error, {:expected, :from_clause}}

  defp parse_optional_limit([]), do: {:ok, nil, []}

  defp parse_optional_limit([{:keyword, :limit}, {:integer, limit} | rest]),
    do: {:ok, limit, rest}

  defp parse_optional_limit([{:keyword, :limit} | _tokens]),
    do: {:error, {:expected, :limit_integer}}

  defp parse_optional_limit(tokens), do: {:ok, nil, tokens}
end
