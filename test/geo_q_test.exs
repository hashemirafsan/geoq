defmodule GeoQTest do
  use ExUnit.Case

  test "version is available as string" do
    assert is_binary(GeoQ.version())
  end
end
