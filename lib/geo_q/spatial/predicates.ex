defmodule GeoQ.Spatial.Predicates do
  @moduledoc """
  Spatial predicate placeholder implementations.
  """

  @spec intersects?(term(), term()) :: {:error, :not_implemented}
  def intersects?(_left_geom, _right_geom), do: {:error, :not_implemented}

  @spec within?(term(), term()) :: {:error, :not_implemented}
  def within?(_left_geom, _right_geom), do: {:error, :not_implemented}

  @spec contains?(term(), term()) :: {:error, :not_implemented}
  def contains?(_left_geom, _right_geom), do: {:error, :not_implemented}

  @spec dwithin?(term(), term(), number()) :: {:error, :not_implemented}
  def dwithin?(_left_geom, _right_geom, _distance_meters), do: {:error, :not_implemented}
end
