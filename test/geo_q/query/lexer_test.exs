defmodule GeoQ.Query.LexerTest do
  use ExUnit.Case, async: true

  alias GeoQ.Query.Lexer

  test "tokenizes select star from limit" do
    assert {:ok, tokens} = Lexer.tokenize("SELECT * FROM climate LIMIT 10")

    assert tokens == [
             {:keyword, :select},
             :star,
             {:keyword, :from},
             {:identifier, "climate"},
             {:keyword, :limit},
             {:integer, 10}
           ]
  end

  test "tokenizes identifier projection list" do
    assert {:ok, tokens} = Lexer.tokenize("select alias, file_path from climate")

    assert tokens == [
             {:keyword, :select},
             {:identifier, "alias"},
             :comma,
             {:identifier, "file_path"},
             {:keyword, :from},
             {:identifier, "climate"}
           ]
  end

  test "returns invalid token error" do
    assert {:error, {:invalid_token, "= climate"}} = Lexer.tokenize("SELECT * FROM = climate")
  end
end
