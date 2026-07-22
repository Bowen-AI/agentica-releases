#!/bin/sh
# Regression tests for install.sh disk-space helper (no network).
# Run: sh scripts/test-install-lib.sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
fail=0

# Mirror of install.sh::require_free_kb
require_free_kb() {
  _path="$1"; _need="$2"; _why="$3"
  _avail="$(df -k "$_path" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [ -z "${_avail:-}" ]; then
    return 0
  fi
  if [ "$_avail" -lt "$_need" ]; then
    return 1
  fi
  return 0
}

# Absurdly large requirement must fail on any real volume.
if require_free_kb "$HOME" 999999999999 "test"; then
  echo "FAIL: expected insufficient space for huge requirement"
  fail=1
else
  echo "OK: huge requirement rejected"
fi

# Tiny requirement must pass.
if require_free_kb "$HOME" 1 "test"; then
  echo "OK: tiny requirement accepted"
else
  echo "FAIL: expected enough space for 1 KB"
  fail=1
fi

# install.sh must define the helper and scrub ELECTRON_RUN_AS_NODE in launchers.
if grep -q 'require_free_kb' "$ROOT/install.sh" \
   && grep -q 'unset ELECTRON_RUN_AS_NODE' "$ROOT/install.sh" \
   && grep -q 'require_free_kb.*600000' "$ROOT/install.sh" \
   && grep -q 'require_free_kb.*5000000\|require_free_kb "\$HOME" 5000000' "$ROOT/install.sh"; then
  echo "OK: install.sh has disk guards + env scrub"
else
  echo "FAIL: install.sh missing disk guards or env scrub"
  fail=1
fi

if [ ! -f "$ROOT/docs/install.sh" ] || ! cmp -s "$ROOT/install.sh" "$ROOT/docs/install.sh"; then
  echo "FAIL: docs/install.sh must match install.sh"
  fail=1
else
  echo "OK: docs/install.sh synced"
fi

exit "$fail"
