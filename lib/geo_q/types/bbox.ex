defmodule GeoQ.Types.BBox do
  @moduledoc """
  Bounding box model.
  """

  @enforce_keys [:min_x, :min_y, :max_x, :max_y]
  defstruct [:min_x, :min_y, :max_x, :max_y]

  @type t :: %__MODULE__{
          min_x: number(),
          min_y: number(),
          max_x: number(),
          max_y: number()
        }
end
