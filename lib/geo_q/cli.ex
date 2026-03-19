defmodule GeoQ.CLI do
  @moduledoc """
  Command-line entrypoint and command dispatcher.

  This module intentionally keeps behavior small for now so we can grow each
  command in vertical slices with tests.
  """

  alias GeoQ.Commands.Inspect
  alias GeoQ.Formatter.CSV
  alias GeoQ.Formatter.JSON
  alias GeoQ.Formatter.Table
  alias GeoQ.Query.Executor
  alias GeoQ.Registry

  @type command_result :: {:ok, String.t()} | {:error, term()}

  @spec main([String.t()]) :: :ok | {:error, term()}
  def main(argv) do
    case dispatch(argv) do
      {:ok, output} ->
        IO.puts(output)
        :ok

      {:error, reason} ->
        IO.puts("Error: #{format_reason(reason)}")
        {:error, reason}
    end
  end

  @spec dispatch([String.t()]) :: command_result()
  def dispatch(["register", file_path | rest]) do
    case OptionParser.parse(rest, strict: [alias: :string]) do
      {[alias: source_alias], [], []} ->
        register_source(source_alias, file_path)

      _ ->
        {:error, :invalid_register_args}
    end
  end

  def dispatch(["unregister", source_alias]) do
    case Registry.unregister(source_alias) do
      :ok -> {:ok, "Unregistered: #{source_alias}"}
      {:error, reason} -> {:error, reason}
    end
  end

  def dispatch(["list"]) do
    entries = Registry.list()

    output =
      case entries do
        [] -> "No registered files"
        _ -> Enum.map_join(entries, "\n", &format_entry/1)
      end

    {:ok, output}
  end

  def dispatch(["inspect" | rest]) do
    case OptionParser.parse(rest, strict: [format: :string]) do
      {opts, [file_path], []} ->
        Inspect.run(file_path, opts)

      _ ->
        {:error, :invalid_inspect_args}
    end
  end

  def dispatch(["query" | rest]) do
    case OptionParser.parse(rest,
           strict: [
             format: :string,
             file: :string,
             pretty: :boolean,
             compact: :boolean,
             no_truncate: :boolean,
             max_cell_length: :integer
           ]
         ) do
      {opts, args, []} ->
        with {:ok, sql} <- resolve_query_sql(opts, args),
             {:ok, result_set} <- Executor.execute(sql) do
          render_query_result(result_set, query_format(opts), opts)
        end

      _ ->
        {:error, :invalid_query_args}
    end
  end

  def dispatch(["repl"]) do
    {:error, :repl_not_implemented}
  end

  def dispatch(_argv) do
    {:error, :unknown_command}
  end

  defp register_source(source_alias, file_path) do
    expanded_path = Path.expand(file_path)

    if File.regular?(expanded_path) do
      case Registry.register(source_alias, %{file_path: file_path}) do
        :ok -> {:ok, "Registered: #{source_alias} -> #{file_path}"}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, {:file_not_found, expanded_path}}
    end
  end

  defp resolve_query_sql(opts, args) do
    query_file = Keyword.get(opts, :file)

    case {query_file, args} do
      {nil, [sql]} ->
        {:ok, sql}

      {file_path, []} when is_binary(file_path) ->
        case File.read(file_path) do
          {:ok, sql} -> {:ok, sql}
          {:error, reason} -> {:error, {:query_file_read_failed, file_path, reason}}
        end

      _ ->
        {:error, :invalid_query_args}
    end
  end

  defp query_format(opts) do
    opts
    |> Keyword.get(:format, "table")
    |> String.downcase()
  end

  defp render_query_result(result_set, "table", opts) do
    with {:ok, table_opts} <- table_style_opts(opts) do
      {:ok, Table.format(result_set, table_opts)}
    end
  end

  defp render_query_result(result_set, "csv", _opts), do: {:ok, CSV.format(result_set)}

  defp render_query_result(result_set, "json", opts),
    do: JSON.format(result_set, json_style(opts))

  defp render_query_result(_result_set, format, _opts),
    do: {:error, {:unsupported_output_format, format}}

  defp json_style(opts) do
    compact? = Keyword.get(opts, :compact, false)
    pretty? = Keyword.get(opts, :pretty, false)

    cond do
      compact? -> :compact
      pretty? -> :pretty
      true -> :pretty
    end
  end

  defp table_style_opts(opts) do
    no_truncate? = Keyword.get(opts, :no_truncate, false)
    max_cell_length = Keyword.get(opts, :max_cell_length)

    cond do
      no_truncate? ->
        {:ok, [truncate: false]}

      is_nil(max_cell_length) ->
        {:ok, []}

      is_integer(max_cell_length) and max_cell_length > 3 ->
        {:ok, [max_cell_length: max_cell_length]}

      true ->
        {:error, {:invalid_max_cell_length, max_cell_length}}
    end
  end

  defp format_entry({source_alias, metadata}) do
    file_path = Map.get(metadata, :file_path) || Map.get(metadata, "file_path") || ""
    "#{source_alias}\t#{file_path}"
  end

  defp format_reason(:invalid_register_args), do: "Usage: geoq register <path> --alias <name>"

  defp format_reason(:invalid_inspect_args),
    do: "Usage: geoq inspect [--format table|json] <path>"

  defp format_reason(:invalid_query_args),
    do:
      "Usage: geoq query [--format table|csv|json] [--compact|--pretty] [--no-truncate|--max-cell-length n] <sql> | geoq query --file <path>"

  defp format_reason(:unknown_command), do: "Unknown command"
  defp format_reason(:repl_not_implemented), do: "repl command not implemented yet"

  defp format_reason({:unsupported_source_format, extension}),
    do: "Unsupported file format: #{extension}"

  defp format_reason({:unsupported_output_format, format}),
    do: "Unsupported output format: #{format}"

  defp format_reason({:file_not_found, file_path}), do: "File not found: #{file_path}"

  defp format_reason(:alias_exists),
    do: "Alias already exists. Use a different alias or unregister first."

  defp format_reason({:persist_failed, reason}), do: "Registry persist failed: #{inspect(reason)}"

  defp format_reason({:source_not_registered, source_alias}),
    do: "Source is not registered: #{source_alias}"

  defp format_reason({:unknown_column, column}), do: "Unknown column in query: #{column}"

  defp format_reason({:unsupported_column, column}),
    do: "Unsupported column in this query path: #{column}"

  defp format_reason({:unexpected_output_columns, headers}),
    do: "Unexpected adapter output columns: #{inspect(headers)}"

  defp format_reason({:invalid_json_style, style}),
    do: "Invalid JSON style: #{inspect(style)}"

  defp format_reason({:invalid_max_cell_length, value}),
    do: "Invalid max cell length: #{inspect(value)} (must be integer > 3)"

  defp format_reason({:query_file_read_failed, file_path, reason}),
    do: "Could not read query file #{file_path}: #{inspect(reason)}"

  defp format_reason({:command_failed, reason}), do: reason
  defp format_reason(reason), do: inspect(reason)
end
