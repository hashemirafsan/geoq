# Rollback Guide

This guide explains how to recover quickly from a bad release.

## 1) Identify last known good version

- check GitHub Releases and CI history
- pick the latest stable tag that passed install smoke

## 2) Re-point Homebrew formula

1. update `Formula/geoq.rb`:
   - `url` to last known good tag tarball
   - matching `sha256`
2. commit and push directly to `main` with a rollback message

Example commit message:

`chore(release): rollback Homebrew formula to vX.Y.Z`

## 3) Validate rollback

On macOS:

```bash
brew update
brew reinstall geoq
geoq --version
```

Then run acceptance smoke:

```bash
GEOQ_BIN=geoq bash scripts/acceptance/macos_user_journey.sh
```

## 4) Communicate and follow up

- post summary of the rollback reason
- open fix PR for broken release issue
- add regression test to prevent repeat
