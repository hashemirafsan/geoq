defmodule GeoQ.Adapters.Netcdf do
  @moduledoc """
  NetCDF adapter implementation backed by `ncdump`.
  """

  @behaviour GeoQ.Adapters.Behaviour

  alias GeoQ.Types.Column
  alias GeoQ.Types.Schema

  @impl true
  def schema(file_path) when is_binary(file_path) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_file(expanded_path),
         {:ok, output} <- ncdump_header(expanded_path),
         columns <- parse_columns(output),
         {:ok, file_stat} <- File.stat(expanded_path, time: :posix) do
      {:ok,
       %Schema{
         source_alias: Path.basename(expanded_path, Path.extname(expanded_path)),
         file_path: expanded_path,
         format: :netcdf,
         columns: columns,
         file_mtime: file_stat.mtime
       }}
    end
  end

  @impl true
  def read_columns(_file_path, _columns, _filters), do: {:error, :not_implemented}

  @impl true
  def spatial_index(_file_path), do: {:error, :not_implemented}

  @impl true
  def bbox(_file_path), do: {:error, :not_implemented}

  defp validate_file(file_path) do
    if File.regular?(file_path) do
      :ok
    else
      {:error, {:file_not_found, file_path}}
    end
  end

  defp ncdump_header(file_path) do
    case System.cmd("ncdump", ["-h", file_path], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _exit_code} -> {:error, {:command_failed, String.trim(output)}}
    end
  rescue
    error in ErlangError ->
      {:error, {:command_failed, Exception.message(error)}}
  end

  defp parse_columns(ncdump_output) do
    lines = String.split(ncdump_output, "\n")

    units_by_variable = parse_units(lines)

    lines
    |> extract_variable_definitions()
    |> Enum.map(fn %{type: type, name: name, dims: dims} ->
      %Column{
        name: name,
        type: normalize_type(type),
        unit: Map.get(units_by_variable, name),
        dims: dims
      }
    end)
  end

  defp parse_units(lines) do
    units_regex = ~r/^([A-Za-z0-9_]+):units\s*=\s*"([^"]*)"\s*;$/

    Enum.reduce(lines, %{}, fn line, acc ->
      trimmed = String.trim(line)

      case Regex.run(units_regex, trimmed) do
        [_, variable_name, unit] -> Map.put(acc, variable_name, unit)
        _ -> acc
      end
    end)
  end

  defp extract_variable_definitions(lines) do
    definition_regex = ~r/^(\w+)\s+([A-Za-z0-9_]+)(?:\(([^)]*)\))?\s*;$/

    {definitions, _in_variables?} =
      Enum.reduce(lines, {[], false}, fn line, {acc, in_variables?} ->
        parse_variable_line(String.trim(line), acc, in_variables?, definition_regex)
      end)

    Enum.reverse(definitions)
  end

  defp parse_variable_line("variables:", acc, _in_variables?, _definition_regex), do: {acc, true}

  defp parse_variable_line("// global attributes:", acc, _in_variables?, _definition_regex),
    do: {acc, false}

  defp parse_variable_line(_trimmed, acc, false, _definition_regex), do: {acc, false}

  defp parse_variable_line(trimmed, acc, true, definition_regex) do
    {parse_variable_definition(trimmed, definition_regex, acc), true}
  end

  defp parse_variable_definition(trimmed, definition_regex, acc) do
    case Regex.run(definition_regex, trimmed) do
      [_, type, variable_name, dims] ->
        parsed_dims = dims |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
        [%{type: type, name: variable_name, dims: parsed_dims} | acc]

      [_, type, variable_name] ->
        [%{type: type, name: variable_name, dims: []} | acc]

      _ ->
        acc
    end
  end

  defp normalize_type("float"), do: :float32
  defp normalize_type("double"), do: :float64
  defp normalize_type("short"), do: :int16
  defp normalize_type("int"), do: :int32
  defp normalize_type("int64"), do: :int64
  defp normalize_type("byte"), do: :int8
  defp normalize_type("char"), do: :string
  defp normalize_type("string"), do: :string
  defp normalize_type(_unknown), do: :unknown
end
