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
  def read_columns(_file_path, _columns, _filters), do: {:error, :not_implemented}

  @impl true
  def spatial_index(_file_path), do: {:error, :not_implemented}

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
