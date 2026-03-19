#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version-tag>" >&2
  echo "Example: $0 v0.1.2" >&2
  exit 1
fi

VERSION_TAG="$1"

if [[ ! "$VERSION_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version tag: $VERSION_TAG (expected vX.Y.Z)" >&2
  exit 1
fi

APP_VERSION="${VERSION_TAG#v}"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required: https://cli.github.com/" >&2
  exit 1
fi

if [[ -n "$(git status --short)" ]]; then
  echo "Working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "You must release from main branch. Current: $CURRENT_BRANCH" >&2
  exit 1
fi

MIX_VERSION="$(python3 - <<'PY'
import re
from pathlib import Path
text = Path('mix.exs').read_text()
m = re.search(r'version:\s*"([^"]+)"', text)
print(m.group(1) if m else '')
PY
)"

if [[ -z "$MIX_VERSION" ]]; then
  echo "Could not read version from mix.exs" >&2
  exit 1
fi

if [[ "$MIX_VERSION" != "$APP_VERSION" ]]; then
  echo "mix.exs version ($MIX_VERSION) does not match tag ($VERSION_TAG)" >&2
  echo "Update mix.exs version to $APP_VERSION first." >&2
  exit 1
fi

if git rev-parse "$VERSION_TAG" >/dev/null 2>&1; then
  echo "Tag already exists locally: $VERSION_TAG" >&2
  exit 1
fi

if git ls-remote --tags origin "$VERSION_TAG" | grep -q "$VERSION_TAG"; then
  echo "Tag already exists on origin: $VERSION_TAG" >&2
  exit 1
fi

echo "==> Running release preflight checks"
make ci
make acceptance-smoke

echo "==> Pushing main"
git push origin main

echo "==> Creating and pushing tag $VERSION_TAG"
git tag -a "$VERSION_TAG" -m "Release $VERSION_TAG"
git push origin "$VERSION_TAG"

echo "==> Creating GitHub release"
gh release create "$VERSION_TAG" --generate-notes --title "$VERSION_TAG"

echo "==> Updating Homebrew formula"
TARBALL_URL="https://github.com/hashemirafsan/geoq/archive/refs/tags/${VERSION_TAG}.tar.gz"
curl -fsSL -o source.tar.gz "$TARBALL_URL"
SHA256="$(shasum -a 256 source.tar.gz | cut -d ' ' -f1)"
rm -f source.tar.gz

bash scripts/release/update_formula.sh "$VERSION_TAG" "$SHA256"

git add Formula/geoq.rb
git commit -m "chore(release): update Homebrew formula for ${VERSION_TAG}"
git push origin main

echo "==> Release complete: $VERSION_TAG"
