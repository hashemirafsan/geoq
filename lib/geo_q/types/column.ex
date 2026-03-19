defmodule GeoQ.Types.Column do
  @moduledoc """
  Column metadata model.
  """

  @enforce_keys [:name, :type]
  defstruct [:name, :type, :unit, dims: []]

  @type t :: %__MODULE__{
          name: String.t(),
          type: atom(),
          unit: String.t() | nil,
          dims: [String.t()]
        }
end
