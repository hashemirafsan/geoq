defmodule GeoQ.Types.ResultSet do
  @moduledoc """
  Query result model.
  """

  @enforce_keys [:columns, :rows]
  defstruct [:metadata, columns: [], rows: []]

  @type row :: [term()] | map()

  @type t :: %__MODULE__{
          columns: [String.t()],
          rows: [row()],
          metadata: map() | nil
        }
end
