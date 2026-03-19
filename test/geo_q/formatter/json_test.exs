defmodule GeoQ.Formatter.JSONTest do
  use ExUnit.Case, async: true

  alias GeoQ.Formatter.JSON
  alias GeoQ.Types.ResultSet

  test "formats result set in pretty json" do
    result_set = %ResultSet{
      columns: ["country"],
      rows: [["Greece"]],
      metadata: %{source: "regions"}
    }

    assert {:ok, output} = JSON.format(result_set, :pretty)
    assert output =~ "\n"

    decoded = Jason.decode!(output)
    assert decoded["rows"] == [%{"country" => "Greece"}]
  end

  test "formats result set in compact json" do
    result_set = %ResultSet{
      columns: ["country"],
      rows: [["Greece"]],
      metadata: %{source: "regions"}
    }

    assert {:ok, output} = JSON.format(result_set, :compact)
    refute output =~ "\n"

    decoded = Jason.decode!(output)
    assert decoded["rows"] == [%{"country" => "Greece"}]
  end

  test "returns error for unknown style" do
    result_set = %ResultSet{columns: [], rows: []}
    assert {:error, {:invalid_json_style, :invalid}} = JSON.format(result_set, :invalid)
  end
end
