%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["config/", "lib/", "test/", "mix.exs"],
        excluded: ["_build/", "deps/"]
      },
      strict: true,
      checks: [
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Readability.Specs, false}
      ]
    }
  ]
}
