#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <version-tag> <sha256>" >&2
  exit 1
fi

VERSION="$1"
SHA="$2"
FORMULA_FILE="Formula/geoq.rb"

if [[ ! -f "$FORMULA_FILE" ]]; then
  echo "Formula file not found: $FORMULA_FILE" >&2
  exit 1
fi

perl -i -pe "s|url \"https://github.com/hashemirafsan/geoq/archive/refs/tags/[^\"]+\.tar\.gz\"|url \"https://github.com/hashemirafsan/geoq/archive/refs/tags/${VERSION}.tar.gz\"|" "$FORMULA_FILE"
perl -i -pe "s|sha256 \"[a-f0-9]{64}\"|sha256 \"${SHA}\"|" "$FORMULA_FILE"

echo "Updated $FORMULA_FILE for ${VERSION}"
