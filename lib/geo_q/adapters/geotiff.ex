defmodule GeoQ.Adapters.GeoTiff do
  @moduledoc """
  GeoTIFF adapter implementation backed by GDAL command-line tools.
  """

  @behaviour GeoQ.Adapters.Behaviour

  alias GeoQ.Types.BBox
  alias GeoQ.Types.Column
  alias GeoQ.Types.Schema

  @impl true
  def schema(file_path) when is_binary(file_path) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_file(expanded_path),
         {:ok, info} <- gdalinfo_json(expanded_path),
         {:ok, file_stat} <- File.stat(expanded_path, time: :posix) do
      {:ok,
       %Schema{
         source_alias: Path.basename(expanded_path, Path.extname(expanded_path)),
         file_path: expanded_path,
         format: :geotiff,
         columns: parse_columns(info),
         bbox: parse_bbox(info),
         crs: parse_crs(info),
         file_mtime: file_stat.mtime
       }}
    end
  end

  @impl true
  def read_columns(file_path, columns, filters)
      when is_binary(file_path) and is_list(columns) and is_list(filters) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_file(expanded_path),
         :ok <- validate_projection(columns),
         {:ok, xyz_output} <- gdal_translate_xyz(expanded_path),
         {:ok, rows} <- parse_xyz_rows(xyz_output),
         {:ok, projected_rows} <- project_rows(rows, columns) do
      {:ok, apply_limit(projected_rows, filters)}
    end
  end

  @impl true
  def spatial_index(_file_path), do: {:error, :not_implemented}

  @impl true
  def bbox(file_path) when is_binary(file_path) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_file(expanded_path),
         {:ok, info} <- gdalinfo_json(expanded_path),
         %BBox{} = bbox <- parse_bbox(info) do
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

  defp gdalinfo_json(file_path) do
    case System.cmd("gdalinfo", ["-json", file_path], stderr_to_stdout: true) do
      {output, 0} -> Jason.decode(output)
      {output, _exit_code} -> {:error, {:command_failed, String.trim(output)}}
    end
  rescue
    error in ErlangError -> {:error, {:command_failed, Exception.message(error)}}
  end

  defp gdal_translate_xyz(file_path) do
    case System.cmd(
           "gdal_translate",
           ["-of", "XYZ", file_path, "/vsistdout/"],
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, output}
      {output, _exit_code} -> {:error, {:command_failed, String.trim(output)}}
    end
  rescue
    error in ErlangError -> {:error, {:command_failed, Exception.message(error)}}
  end

  defp parse_columns(info) do
    band_columns =
      info
      |> Map.get("bands", [])
      |> Enum.map(fn band ->
        band_number = Map.get(band, "band", 1)
        type_name = Map.get(band, "type", "Unknown")

        %Column{
          name: "band_#{band_number}",
          type: normalize_raster_type(type_name),
          unit: nil,
          dims: ["row", "col"]
        }
      end)

    [
      %Column{name: "x", type: :float64, unit: nil, dims: []},
      %Column{name: "y", type: :float64, unit: nil, dims: []}
    ] ++ band_columns
  end

  defp parse_bbox(info) do
    corners = Map.get(info, "cornerCoordinates", %{})

    points =
      [
        Map.get(corners, "upperLeft"),
        Map.get(corners, "lowerLeft"),
        Map.get(corners, "upperRight"),
        Map.get(corners, "lowerRight")
      ]
      |> Enum.filter(&is_list/1)

    case points do
      [] ->
        nil

      _ ->
        xs = Enum.map(points, &Enum.at(&1, 0))
        ys = Enum.map(points, &Enum.at(&1, 1))
        %BBox{min_x: Enum.min(xs), min_y: Enum.min(ys), max_x: Enum.max(xs), max_y: Enum.max(ys)}
    end
  end

  defp parse_crs(info) do
    case get_in(info, ["stac", "proj:epsg"]) do
      epsg when is_integer(epsg) -> "EPSG:#{epsg}"
      _ -> nil
    end
  end

  defp validate_projection(columns) do
    Enum.reduce_while(columns, :ok, fn column_name, :ok ->
      cond do
        column_name in ["x", "y", "band_1"] ->
          {:cont, :ok}

        String.starts_with?(column_name, "band_") ->
          {:halt, {:error, {:unsupported_band, column_name}}}

        true ->
          {:halt, {:error, {:unknown_column, column_name}}}
      end
    end)
  end

  defp parse_xyz_rows(output) do
    rows =
      output
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&parse_xyz_row/1)

    if Enum.any?(rows, &match?({:error, _}, &1)) do
      {:error, :invalid_raster_data}
    else
      {:ok, Enum.map(rows, fn {:ok, row} -> row end)}
    end
  end

  defp parse_xyz_row(line) do
    parts = String.split(line, ~r/\s+/, trim: true)

    case parts do
      [x, y, value] ->
        with {xv, ""} <- Float.parse(x),
             {yv, ""} <- Float.parse(y),
             parsed_value <- parse_xyz_value(value) do
          {:ok, %{"x" => xv, "y" => yv, "band_1" => parsed_value}}
        else
          _ -> {:error, :invalid_xyz_row}
        end

      _ ->
        {:error, :invalid_xyz_row}
    end
  end

  defp parse_xyz_value(value) do
    case Float.parse(value) do
      {float_value, ""} -> float_value
      _ -> value
    end
  end

  defp project_rows(rows, columns) do
    Enum.reduce_while(rows, {:ok, []}, fn row, {:ok, acc} ->
      case project_row(row, columns) do
        {:ok, projected} -> {:cont, {:ok, [projected | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, projected_rows} -> {:ok, Enum.reverse(projected_rows)}
      {:error, _reason} = error -> error
    end
  end

  defp project_row(row, columns) do
    Enum.reduce_while(columns, {:ok, %{}}, fn column, {:ok, projected} ->
      case Map.fetch(row, column) do
        {:ok, value} -> {:cont, {:ok, Map.put(projected, column, value)}}
        :error -> {:halt, {:error, {:unknown_column, column}}}
      end
    end)
  end

  defp apply_limit(rows, filters) do
    case Keyword.get(filters, :limit) do
      nil -> rows
      limit when is_integer(limit) and limit <= 0 -> []
      limit when is_integer(limit) -> Enum.take(rows, limit)
      _ -> rows
    end
  end

  defp normalize_raster_type("Float32"), do: :float32
  defp normalize_raster_type("Float64"), do: :float64
  defp normalize_raster_type("Int16"), do: :int16
  defp normalize_raster_type("Int32"), do: :int32
  defp normalize_raster_type("UInt16"), do: :int16
  defp normalize_raster_type("UInt32"), do: :int32
  defp normalize_raster_type("Byte"), do: :int8
  defp normalize_raster_type(_), do: :unknown
end
