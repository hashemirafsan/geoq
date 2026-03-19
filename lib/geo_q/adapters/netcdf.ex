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
  def read_columns(file_path, columns, filters)
      when is_binary(file_path) and is_list(columns) and is_list(filters) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_file(expanded_path),
         {:ok, %Schema{} = schema} <- schema(expanded_path),
         {:ok, selected_columns} <- resolve_selected_columns(schema, columns),
         {:ok, values_by_column} <- load_column_values(expanded_path, selected_columns) do
      build_rows(selected_columns, values_by_column, filters)
    end
  end

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

  defp ncdump_variable(file_path, variable) do
    case System.cmd("ncdump", ["-v", variable, file_path], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _exit_code} -> {:error, {:command_failed, String.trim(output)}}
    end
  rescue
    error in ErlangError ->
      {:error, {:command_failed, Exception.message(error)}}
  end

  defp resolve_selected_columns(%Schema{columns: schema_columns}, columns) do
    columns_by_name = Map.new(schema_columns, fn column -> {column.name, column} end)

    Enum.reduce_while(columns, {:ok, []}, fn column_name, {:ok, acc} ->
      case Map.get(columns_by_name, column_name) do
        nil ->
          {:halt, {:error, {:unknown_column, column_name}}}

        %Column{dims: dims} = column when length(dims) <= 1 ->
          {:cont, {:ok, acc ++ [column]}}

        %Column{dims: dims} ->
          {:halt, {:error, {:unsupported_dimensions, column_name, dims}}}
      end
    end)
  end

  defp load_column_values(file_path, selected_columns) do
    Enum.reduce_while(selected_columns, {:ok, %{}}, fn %Column{name: name}, {:ok, acc} ->
      with {:ok, output} <- ncdump_variable(file_path, name),
           {:ok, values} <- extract_variable_values(output, name) do
        {:cont, {:ok, Map.put(acc, name, values)}}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp extract_variable_values(output, variable_name) do
    case String.split(output, "data:", parts: 2) do
      [_header, data_section] ->
        variable_regex = ~r/#{Regex.escape(variable_name)}\s*=\s*(.*?);/ms

        case Regex.run(variable_regex, data_section) do
          [_, values_blob] ->
            {:ok,
             values_blob
             |> String.replace("\n", " ")
             |> String.split(",", trim: true)
             |> Enum.map(&String.trim/1)
             |> Enum.map(&parse_cdl_value/1)}

          _ ->
            {:error, {:invalid_netcdf_data, variable_name}}
        end

      _ ->
        {:error, {:invalid_netcdf_output, variable_name}}
    end
  end

  defp parse_cdl_value(token) do
    cleaned = String.trim(token)

    cond do
      cleaned in ["NaN", "NaNf", "nan", "nanf", "_"] ->
        nil

      Regex.match?(~r/^-?\d+(?:[uUlL]+)?$/, cleaned) ->
        cleaned
        |> String.replace(~r/[uUlL]+$/, "")
        |> String.to_integer()

      true ->
        parse_float_or_string(cleaned)
    end
  end

  defp parse_float_or_string(cleaned) do
    candidate = cleaned |> String.trim_trailing("f") |> String.trim_trailing("F")

    case Float.parse(candidate) do
      {value, ""} -> value
      _ -> String.trim(cleaned, "\"")
    end
  end

  defp build_rows(selected_columns, values_by_column, filters) do
    lengths =
      Enum.map(selected_columns, fn %Column{name: name} ->
        values_by_column |> Map.fetch!(name) |> length()
      end)

    row_count = Enum.max([0 | lengths])

    case validate_lengths(selected_columns, values_by_column, row_count) do
      :ok ->
        rows = build_row_maps(selected_columns, values_by_column, row_count)

        {:ok, apply_limit(rows, filters)}

      {:error, _reason} = error ->
        error
    end
  end

  defp validate_lengths(selected_columns, values_by_column, row_count) do
    Enum.reduce_while(selected_columns, :ok, fn %Column{name: name}, :ok ->
      count = values_by_column |> Map.fetch!(name) |> length()

      cond do
        count == row_count -> {:cont, :ok}
        count == 1 -> {:cont, :ok}
        row_count == 0 -> {:cont, :ok}
        true -> {:halt, {:error, {:incompatible_column_dimensions, name}}}
      end
    end)
  end

  defp build_row_maps(_selected_columns, _values_by_column, 0), do: []

  defp build_row_maps(selected_columns, values_by_column, row_count) do
    for row_index <- 0..(row_count - 1) do
      build_row(selected_columns, values_by_column, row_index)
    end
  end

  defp build_row(selected_columns, values_by_column, row_index) do
    Enum.reduce(selected_columns, %{}, fn %Column{name: name}, acc ->
      values = Map.fetch!(values_by_column, name)
      value = value_at(values, row_index)
      Map.put(acc, name, value)
    end)
  end

  defp value_at([], _row_index), do: nil
  defp value_at([single], _row_index), do: single
  defp value_at(values, row_index), do: Enum.at(values, row_index)

  defp apply_limit(rows, filters) do
    limit = Keyword.get(filters, :limit)

    case limit do
      nil -> rows
      number when is_integer(number) and number <= 0 -> []
      number when is_integer(number) -> Enum.take(rows, number)
      _ -> rows
    end
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
