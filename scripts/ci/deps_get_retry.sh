#!/usr/bin/env bash

set -euo pipefail

MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"

attempt=1
while (( attempt <= MAX_ATTEMPTS )); do
  if mix deps.get; then
    exit 0
  fi

  if (( attempt == MAX_ATTEMPTS )); then
    echo "mix deps.get failed after ${MAX_ATTEMPTS} attempts" >&2
    exit 1
  fi

  echo "mix deps.get failed (attempt ${attempt}/${MAX_ATTEMPTS}), retrying in ${SLEEP_SECONDS}s..." >&2
  sleep "${SLEEP_SECONDS}"
  attempt=$((attempt + 1))
done
