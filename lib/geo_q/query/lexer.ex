defmodule GeoQ.Query.Lexer do
  @moduledoc """
  Minimal SQL lexer for GeoQ query subset.

  Supported tokens:
  - SELECT, FROM, LIMIT keywords
  - identifiers
  - integer literals
  - `*` and `,`
  """

  @type token ::
          {:keyword, :select | :from | :limit}
          | {:identifier, String.t()}
          | {:integer, non_neg_integer()}
          | :star
          | :comma

  @spec tokenize(String.t()) :: {:ok, [token()]} | {:error, term()}
  def tokenize(sql) when is_binary(sql) do
    do_tokenize(String.trim_leading(sql), [])
  end

  defp do_tokenize("", acc), do: {:ok, Enum.reverse(acc)}

  defp do_tokenize(sql, acc) do
    cond do
      Regex.match?(~r/^\s+/, sql) ->
        [space | _] = Regex.run(~r/^\s+/, sql)
        do_tokenize(String.trim_leading(String.replace_prefix(sql, space, "")), acc)

      String.starts_with?(sql, "*") ->
        do_tokenize(String.slice(sql, 1..-1//1) || "", [:star | acc])

      String.starts_with?(sql, ",") ->
        do_tokenize(String.slice(sql, 1..-1//1) || "", [:comma | acc])

      Regex.match?(~r/^\d+/, sql) ->
        [digits | _] = Regex.run(~r/^\d+/, sql)
        token = {:integer, String.to_integer(digits)}
        rest = String.replace_prefix(sql, digits, "")
        do_tokenize(rest, [token | acc])

      Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_]*/, sql) ->
        [word | _] = Regex.run(~r/^[A-Za-z_][A-Za-z0-9_]*/, sql)
        token = classify_word(word)
        rest = String.replace_prefix(sql, word, "")
        do_tokenize(rest, [token | acc])

      true ->
        snippet = String.slice(sql, 0, 16)
        {:error, {:invalid_token, snippet}}
    end
  end

  defp classify_word(word) do
    case String.downcase(word) do
      "select" -> {:keyword, :select}
      "from" -> {:keyword, :from}
      "limit" -> {:keyword, :limit}
      _ -> {:identifier, word}
    end
  end
end
