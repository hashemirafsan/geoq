defmodule GeoQ.Adapters.Behaviour do
  @moduledoc """
  Shared callback contract for file format adapters.
  """

  alias GeoQ.Types.BBox
  alias GeoQ.Types.Schema

  @callback schema(file_path :: String.t()) :: {:ok, Schema.t()} | {:error, term()}
  @callback read_columns(file_path :: String.t(), columns :: [String.t()], filters :: [term()]) ::
              {:ok, term()} | {:error, term()}
  @callback spatial_index(file_path :: String.t()) :: {:ok, term()} | {:error, term()}
  @callback bbox(file_path :: String.t()) :: {:ok, BBox.t()} | {:error, term()}
end
