ExUnit.start(seed: 0)

"test/support/**/*.exs"
|> Path.wildcard()
|> Enum.sort()
|> Enum.each(&Code.require_file/1)
