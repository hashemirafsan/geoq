defmodule GeoQ.TestSupport do
  @moduledoc false

  @spec temp_storage_path(String.t()) :: String.t()
  def temp_storage_path(prefix) when is_binary(prefix) do
    unique = System.unique_integer([:positive])
    Path.join(System.tmp_dir!(), "#{prefix}-#{unique}/registry.json")
  end

  @spec unique_registry_name(String.t()) :: {:global, {String.t(), pos_integer()}}
  def unique_registry_name(prefix \\ "registry") when is_binary(prefix) do
    {:global, {prefix, System.unique_integer([:positive])}}
  end
end
