defmodule GeoQ.Query.ParserTest do
  use ExUnit.Case, async: true

  alias GeoQ.Query.Parser

  test "parses star projection with limit" do
    assert {:ok, ast} = Parser.parse("SELECT * FROM climate LIMIT 5")

    assert ast == %{select: :all, from: "climate", limit: 5}
  end

  test "parses explicit projection list" do
    assert {:ok, ast} = Parser.parse("SELECT alias, file_path FROM climate")

    assert ast == %{select: ["alias", "file_path"], from: "climate", limit: nil}
  end

  test "returns parse error for missing from clause" do
    assert {:error, {:expected, :from_clause}} = Parser.parse("SELECT alias climate")
  end

  test "returns parse error for invalid limit" do
    assert {:error, {:expected, :limit_integer}} =
             Parser.parse("SELECT * FROM climate LIMIT nope")
  end
end
