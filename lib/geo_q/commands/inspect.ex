defmodule GeoQ.Commands.Inspect do
  @moduledoc """
  Handles file inspection command dispatch and output formatting.
  """

  alias GeoQ.Adapters.GeoTiff
  alias GeoQ.Adapters.Netcdf
  alias GeoQ.Adapters.Shapefile
  alias GeoQ.Types.BBox
  alias GeoQ.Types.Schema

  @type command_result :: {:ok, String.t()} | {:error, term()}

  @spec run(String.t(), keyword()) :: command_result()
  def run(file_path, opts \\ []) when is_binary(file_path) do
    output_format = opts |> Keyword.get(:format, "table") |> String.downcase()

    with {:ok, schema} <- inspect_schema(file_path) do
      render(schema, output_format)
    end
  end

  defp inspect_schema(file_path) do
    case String.downcase(Path.extname(file_path)) do
      ".nc" -> Netcdf.schema(file_path)
      ".shp" -> Shapefile.schema(file_path)
      ".tif" -> GeoTiff.schema(file_path)
      ".tiff" -> GeoTiff.schema(file_path)
      extension -> {:error, {:unsupported_source_format, extension}}
    end
  end

  defp render(%Schema{} = schema, "table"), do: {:ok, to_table(schema)}

  defp render(%Schema{} = schema, "json") do
    schema
    |> to_json_map()
    |> Jason.encode(pretty: true)
  end

  defp render(_schema, format), do: {:error, {:unsupported_output_format, format}}

  defp to_table(%Schema{} = schema) do
    header = [
      "File: #{schema.file_path}",
      "Format: #{schema.format}",
      "Columns: #{length(schema.columns)}",
      "",
      "name\ttype\tunit\tdimensions"
    ]

    rows =
      Enum.map(schema.columns, fn column ->
        dims = if column.dims == [], do: "-", else: Enum.join(column.dims, " x ")
        unit = column.unit || "-"
        "#{column.name}\t#{column.type}\t#{unit}\t#{dims}"
      end)

    Enum.join(header ++ rows, "\n")
  end

  defp to_json_map(%Schema{} = schema) do
    %{
      source_alias: schema.source_alias,
      file_path: schema.file_path,
      format: to_string(schema.format),
      crs: schema.crs,
      registered_at: schema.registered_at,
      file_mtime: schema.file_mtime,
      bbox: to_bbox_map(schema.bbox),
      columns:
        Enum.map(schema.columns, fn column ->
          %{
            name: column.name,
            type: to_string(column.type),
            unit: column.unit,
            dims: column.dims
          }
        end)
    }
  end

  defp to_bbox_map(nil), do: nil

  defp to_bbox_map(%BBox{} = bbox) do
    %{min_x: bbox.min_x, min_y: bbox.min_y, max_x: bbox.max_x, max_y: bbox.max_y}
  end
end
