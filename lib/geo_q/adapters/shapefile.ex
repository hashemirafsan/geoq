defmodule GeoQ.Adapters.Shapefile do
  @moduledoc """
  Shapefile adapter implementation backed by `ogrinfo`.
  """

  @behaviour GeoQ.Adapters.Behaviour

  alias GeoQ.Types.BBox
  alias GeoQ.Types.Column
  alias GeoQ.Types.Schema

  @impl true
  def schema(file_path) when is_binary(file_path) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_file(expanded_path),
         {:ok, output} <- ogrinfo_summary(expanded_path),
         {:ok, file_stat} <- File.stat(expanded_path, time: :posix) do
      layer_name =
        parse_layer_name(output) || Path.basename(expanded_path, Path.extname(expanded_path))

      geometry_type = parse_geometry(output)

      {:ok,
       %Schema{
         source_alias: layer_name,
         file_path: expanded_path,
         format: :shapefile,
         columns: build_columns(output, geometry_type),
         bbox: parse_bbox(output),
         crs: parse_crs(output),
         file_mtime: file_stat.mtime
       }}
    end
  end

  @impl true
  def read_columns(file_path, columns, filters)
      when is_binary(file_path) and is_list(columns) and is_list(filters) do
    expanded_path = Path.expand(file_path)
    include_geom = Enum.member?(columns, "geom")
    attribute_columns = Enum.reject(columns, &(&1 == "geom"))

    with :ok <- validate_file(expanded_path),
         {:ok, %Schema{} = schema} <- schema(expanded_path),
         :ok <- validate_projection(columns, schema),
         {:ok, output} <-
           ogr2ogr_tsv(
             expanded_path,
             schema.source_alias,
             attribute_columns,
             filters,
             include_geom
           ),
         {:ok, rows} <- parse_tsv_rows(output, columns, include_geom) do
      {:ok, apply_limit(rows, filters)}
    end
  end

  @impl true
  def spatial_index(file_path) when is_binary(file_path) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_file(expanded_path),
         {:ok, output} <- ogrinfo_summary(expanded_path),
         %BBox{} = bbox <- parse_bbox(output),
         {:ok, file_stat} <- File.stat(expanded_path, time: :posix) do
      {:ok,
       %{
         index_type: :bbox_vector,
         layer_name: parse_layer_name(output),
         feature_count: parse_feature_count(output),
         bbox: bbox,
         file_mtime: file_stat.mtime
       }}
    else
      nil -> {:error, {:spatial_index_unavailable, :bbox_not_found}}
      {:error, _reason} = error -> error
    end
  end

  @impl true
  def bbox(file_path) when is_binary(file_path) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_file(expanded_path),
         {:ok, output} <- ogrinfo_summary(expanded_path),
         %BBox{} = bbox <- parse_bbox(output) do
      {:ok, bbox}
    else
      nil -> {:error, :bbox_not_found}
      {:error, _reason} = error -> error
    end
  end

  defp validate_file(file_path) do
    if File.regular?(file_path) do
      :ok
    else
      {:error, {:file_not_found, file_path}}
    end
  end

  defp ogrinfo_summary(file_path) do
    case System.cmd("ogrinfo", ["-so", "-al", file_path], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _exit_code} -> {:error, {:command_failed, String.trim(output)}}
    end
  rescue
    error in ErlangError ->
      {:error, {:command_failed, Exception.message(error)}}
  end

  defp ogr2ogr_tsv(file_path, layer_name, attribute_columns, filters, include_geom) do
    sql = build_sql(layer_name, attribute_columns, filters)

    args =
      ["-f", "CSV", "/vsistdout/", file_path, "-lco", "SEPARATOR=TAB"] ++
        geometry_lco_args(include_geom) ++
        ["-dialect", "OGRSQL", "-sql", sql]

    case System.cmd(
           "ogr2ogr",
           args,
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, output}
      {output, _exit_code} -> {:error, {:command_failed, String.trim(output)}}
    end
  rescue
    error in ErlangError ->
      {:error, {:command_failed, Exception.message(error)}}
  end

  defp validate_projection(columns, %Schema{columns: schema_columns}) do
    known_columns = MapSet.new(schema_columns, & &1.name)

    Enum.reduce_while(columns, :ok, fn column_name, _acc ->
      if valid_projection_column?(column_name, known_columns) do
        {:cont, :ok}
      else
        {:halt, {:error, {:unknown_column, column_name}}}
      end
    end)
  end

  defp valid_projection_column?("geom", _known_columns), do: true

  defp valid_projection_column?(column_name, known_columns),
    do: MapSet.member?(known_columns, column_name)

  defp parse_tsv_rows(output, selected_columns, include_geom) do
    lines = String.split(output, "\n", trim: true)

    case lines do
      [] ->
        {:ok, []}

      [header | data_lines] ->
        headers = parse_headers(header)

        data_lines
        |> Enum.map(&parse_tsv_row(&1, headers))
        |> project_rows(selected_columns, include_geom)
    end
  end

  defp parse_headers(header_line) do
    header_line
    |> String.split("\t")
    |> Enum.reject(&(&1 == ""))
  end

  defp project_rows(raw_rows, selected_columns, include_geom) do
    Enum.reduce_while(raw_rows, {:ok, []}, fn raw_row, {:ok, acc} ->
      case project_row(raw_row, selected_columns, include_geom) do
        {:ok, projected_row} -> {:cont, {:ok, acc ++ [projected_row]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp project_row(raw_row, selected_columns, include_geom) do
    Enum.reduce_while(selected_columns, {:ok, %{}}, fn column, {:ok, acc} ->
      source_column = if column == "geom" and include_geom, do: "WKT", else: column

      if Map.has_key?(raw_row, source_column) do
        {:cont, {:ok, Map.put(acc, column, Map.get(raw_row, source_column))}}
      else
        {:halt, {:error, {:unexpected_output_columns, Map.keys(raw_row)}}}
      end
    end)
  end

  defp parse_tsv_row(line, headers) do
    values = String.split(line, "\t")
    padded_values = values ++ List.duplicate(nil, max(length(headers) - length(values), 0))

    headers
    |> Enum.zip(padded_values)
    |> Enum.reduce(%{}, fn {header, value}, acc ->
      Map.put(acc, header, normalize_tsv_value(value))
    end)
  end

  defp normalize_tsv_value(nil), do: nil

  defp normalize_tsv_value(value) do
    cleaned = value |> String.trim() |> String.trim("\"")
    if cleaned == "", do: nil, else: cleaned
  end

  defp apply_limit(rows, filters) do
    case Keyword.get(filters, :limit) do
      nil -> rows
      limit when is_integer(limit) and limit <= 0 -> []
      limit when is_integer(limit) -> Enum.take(rows, limit)
      _ -> rows
    end
  end

  defp build_sql(layer_name, attribute_columns, filters) do
    projection =
      case attribute_columns do
        [] -> "FID"
        _ -> Enum.join(attribute_columns, ", ")
      end

    limit_clause =
      case Keyword.get(filters, :limit) do
        limit when is_integer(limit) and limit > 0 -> " LIMIT #{limit}"
        _ -> ""
      end

    "SELECT #{projection} FROM #{layer_name}#{limit_clause}"
  end

  defp geometry_lco_args(true), do: ["-lco", "GEOMETRY=AS_WKT"]
  defp geometry_lco_args(false), do: []

  defp parse_layer_name(output) do
    case Regex.run(~r/^Layer name:\s*(.+)$/m, output) do
      [_, layer_name] -> String.trim(layer_name)
      _ -> nil
    end
  end

  defp parse_geometry(output) do
    case Regex.run(~r/^Geometry:\s*(.+)$/m, output) do
      [_, geometry] -> String.trim(geometry)
      _ -> "Unknown"
    end
  end

  defp parse_bbox(output) do
    extent_regex =
      ~r/^Extent:\s*\(([-\d\.]+),\s*([-\d\.]+)\)\s*-\s*\(([-\d\.]+),\s*([-\d\.]+)\)$/m

    case Regex.run(extent_regex, output) do
      [_, min_x, min_y, max_x, max_y] ->
        %BBox{
          min_x: String.to_float(min_x),
          min_y: String.to_float(min_y),
          max_x: String.to_float(max_x),
          max_y: String.to_float(max_y)
        }

      _ ->
        nil
    end
  end

  defp parse_crs(output) do
    case Regex.run(~r/ID\["EPSG",\s*(\d+)\]/, output) do
      [_, epsg_code] -> "EPSG:#{epsg_code}"
      _ -> nil
    end
  end

  defp parse_feature_count(output) do
    case Regex.run(~r/^Feature Count:\s*(\d+)$/m, output) do
      [_, count] -> String.to_integer(count)
      _ -> nil
    end
  end

  defp build_columns(output, geometry_type) do
    [geometry_column(geometry_type) | parse_attribute_columns(output)]
  end

  defp geometry_column(geometry_type) do
    %Column{name: "geom", type: normalize_geometry_type(geometry_type), unit: nil, dims: []}
  end

  defp parse_attribute_columns(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(String.contains?(&1, ":") and String.contains?(&1, "(")))
    |> Enum.map(&parse_attribute_column/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_attribute_column(line) do
    case Regex.run(~r/^([A-Za-z0-9_]+):\s*([A-Za-z]+)\s*\(([^\)]*)\)$/, line) do
      [_, column_name, type_name, _size] ->
        %Column{name: column_name, type: normalize_attribute_type(type_name), unit: nil, dims: []}

      _ ->
        nil
    end
  end

  defp normalize_geometry_type(type_name) do
    case String.downcase(type_name) do
      "point" -> :point
      "linestring" -> :linestring
      "polygon" -> :polygon
      "multipoint" -> :multipoint
      "multilinestring" -> :multilinestring
      "multipolygon" -> :multipolygon
      _ -> :geometry
    end
  end

  defp normalize_attribute_type(type_name) do
    case String.downcase(type_name) do
      "string" -> :string
      "integer" -> :int32
      "integer64" -> :int64
      "real" -> :float64
      "date" -> :date
      "datetime" -> :datetime
      _ -> :unknown
    end
  end
end
