defmodule GeoQ.Types.Schema do
  @moduledoc """
  File registration and schema metadata model.
  """

  alias GeoQ.Types.BBox
  alias GeoQ.Types.Column

  @enforce_keys [:source_alias, :file_path, :format]
  defstruct [
    :source_alias,
    :file_path,
    :format,
    :crs,
    :registered_at,
    :file_mtime,
    columns: [],
    bbox: nil
  ]

  @type t :: %__MODULE__{
          source_alias: String.t(),
          file_path: String.t(),
          format: atom(),
          columns: [Column.t()],
          bbox: BBox.t() | nil,
          crs: String.t() | nil,
          registered_at: DateTime.t() | nil,
          file_mtime: integer() | nil
        }
end
