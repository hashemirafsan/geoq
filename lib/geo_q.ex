defmodule GeoQ do
  @moduledoc """
  GeoQ is a CLI-first geospatial file query engine.

  This module acts as a thin application-level facade while the core
  responsibilities live under `GeoQ.*` namespaces.
  """

  @doc """
  Returns current application version from Mix project metadata.
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:geoq, :vsn)
    |> to_string()
  end
end
