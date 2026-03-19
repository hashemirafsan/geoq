# Contributor Checklist

Run this checklist before opening a PR.

## Required

- [ ] branch is up to date with `main`
- [ ] `make ci` passes locally
- [ ] changed behavior has tests
- [ ] new `{:error, ...}` branches have failure-path tests
- [ ] docs updated for user-visible changes

## If CLI behavior changed

- [ ] update `docs/00-quickstart-docker.md`
- [ ] update acceptance script if needed:
  - `scripts/acceptance/macos_user_journey.sh`

## If release/distribution changed

- [ ] update `Formula/geoq.rb` (or release automation)
- [ ] update `docs/release-checklist.md`
- [ ] update `docs/rollback.md` if rollback flow changed

## Final verification commands

```bash
make ci
make acceptance-smoke
```
