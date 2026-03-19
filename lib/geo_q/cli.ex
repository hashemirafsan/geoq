defmodule GeoQ.CLI do
  @moduledoc """
  Command-line entrypoint and command dispatcher.

  This module intentionally keeps behavior small for now so we can grow each
  command in vertical slices with tests.
  """

  alias GeoQ.Commands.Inspect
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

  def dispatch(["query" | _]) do
    {:error, :query_not_implemented}
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

  defp format_entry({source_alias, metadata}) do
    file_path = Map.get(metadata, :file_path) || Map.get(metadata, "file_path") || ""
    "#{source_alias}\t#{file_path}"
  end

  defp format_reason(:invalid_register_args), do: "Usage: geoq register <path> --alias <name>"

  defp format_reason(:invalid_inspect_args),
    do: "Usage: geoq inspect [--format table|json] <path>"

  defp format_reason(:unknown_command), do: "Unknown command"
  defp format_reason(:query_not_implemented), do: "query command not implemented yet"
  defp format_reason(:repl_not_implemented), do: "repl command not implemented yet"

  defp format_reason({:unsupported_source_format, extension}),
    do: "Unsupported file format: #{extension}"

  defp format_reason({:unsupported_output_format, format}),
    do: "Unsupported output format: #{format}"

  defp format_reason({:file_not_found, file_path}), do: "File not found: #{file_path}"

  defp format_reason(:alias_exists),
    do: "Alias already exists. Use a different alias or unregister first."

  defp format_reason({:persist_failed, reason}), do: "Registry persist failed: #{inspect(reason)}"
  defp format_reason({:command_failed, reason}), do: reason
  defp format_reason(reason), do: inspect(reason)
end
