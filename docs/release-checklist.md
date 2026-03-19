# Release Checklist

Use this checklist for production releases (starting with `v0.1.0`).

Current mode: local-driven releases for initial versions.

## 1) Pre-release

- ensure `main` is green (`docker-ci`, `macos-install-smoke`)
- run locally:
  - `make ci`
  - `make acceptance-smoke`
- verify docs are updated for user-visible behavior changes
- verify `mix.exs` version matches planned release

## 2) Release from local

Preferred command:

```bash
make release-local VERSION=v0.1.0
```

This runs:

- `make ci`
- `make acceptance-smoke`
- push `main`
- create/push tag
- create GitHub release (`gh release create`)
- update `Formula/geoq.rb` with pinned tarball sha256
- commit/push formula update

## 3) Manual fallback steps

```bash
git checkout main
git pull --ff-only
make ci
make acceptance-smoke
git push origin main
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
gh release create v0.1.0 --generate-notes --title v0.1.0
```

Then update formula:

```bash
curl -fsSL -o source.tar.gz "https://github.com/hashemirafsan/geoq/archive/refs/tags/v0.1.0.tar.gz"
SHA256=$(shasum -a 256 source.tar.gz | cut -d ' ' -f1)
bash scripts/release/update_formula.sh v0.1.0 "$SHA256"
git add Formula/geoq.rb
git commit -m "chore(release): update Homebrew formula for v0.1.0"
git push origin main
```

## 4) Post-release verification

On a clean macOS machine:

```bash
brew tap hashemirafsan/geoq
brew install geoq
geoq --version
geoq doctor
```

Then run acceptance smoke:

```bash
GEOQ_BIN=geoq bash scripts/acceptance/macos_user_journey.sh
```

## 5) If release fails

- follow `docs/rollback.md`
- open incident note with failing step and logs
