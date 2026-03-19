class Geoq < Formula
  desc "CLI geospatial file-native query engine"
  homepage "https://github.com/hashemirafsan/geoq"
  url "https://github.com/hashemirafsan/geoq/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "8c0ad269a2984be3d2cb2122dde3e643ebb06b6cc8653a35202bc3b89244a9b4"
  head "https://github.com/hashemirafsan/geoq.git", branch: "main"

  depends_on "elixir" => :build
  depends_on "erlang"
  depends_on "gdal"
  depends_on "netcdf"

  def install
    system "mix", "local.hex", "--force"
    system "mix", "local.rebar", "--force"
    system "mix", "deps.get", "--only", "prod"
    system "mix", "escript.build"
    bin.install "geoq"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/geoq --version")
    assert_match "No registered files", shell_output("#{bin}/geoq list")
  end
end
