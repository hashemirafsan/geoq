defmodule GeoQ.Formatter.TableTest do
  use ExUnit.Case, async: true

  alias GeoQ.Formatter.Table
  alias GeoQ.Types.ResultSet

  test "truncates very long values" do
    long_value = String.duplicate("A", 200)
    result_set = %ResultSet{columns: ["geom"], rows: [[long_value]]}

    output = Table.format(result_set)
    assert output =~ "geom"
    assert output =~ "..."
    refute output =~ long_value
  end

  test "renders nil as empty value" do
    result_set = %ResultSet{columns: ["name", "value"], rows: [["x", nil]]}
    output = Table.format(result_set)

    assert output =~ "name | value"
    assert output =~ "x | "
  end
end
