# Release Checklist

Use this checklist for production releases (starting with `v0.1.0`).

## 1) Pre-release

- ensure `main` is green (`docker-ci`, `macos-install-smoke`)
- run locally:
  - `make ci`
  - `make acceptance-smoke`
- verify docs are updated for user-visible behavior changes
- verify `mix.exs` version matches planned release

## 2) Tag and release

```bash
git checkout main
git pull --ff-only
git tag v0.1.0
git push origin v0.1.0
```

Release workflow does:

- full verification (`make ci`)
- GitHub Release publication
- Homebrew formula update (`Formula/geoq.rb`) with tagged tarball + sha256
- macOS install smoke from tap

## 3) Post-release verification

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

## 4) If release fails

- follow `docs/rollback.md`
- open incident note with failing step and logs
