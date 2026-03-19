defmodule GeoQ.Adapters.GeoTiff do
  @moduledoc """
  GeoTIFF adapter placeholder.
  """

  @behaviour GeoQ.Adapters.Behaviour

  @impl true
  def schema(_file_path), do: {:error, :not_implemented}

  @impl true
  def read_columns(_file_path, _columns, _filters), do: {:error, :not_implemented}

  @impl true
  def spatial_index(_file_path), do: {:error, :not_implemented}

  @impl true
  def bbox(_file_path), do: {:error, :not_implemented}
end
