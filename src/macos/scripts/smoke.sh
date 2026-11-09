#!/usr/bin/env bash
#
# Minimal post-build smoke check for the macOS app bundle. This never launches
# or automates the GUI; it only validates the packaged artifact.
#
# Usage:
#   src/macos/scripts/smoke.sh
#
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: smoke.sh must run on macOS (Darwin)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

fail() {
  echo "SMOKE FAIL: $*" >&2
  exit 1
}

# 1) Optional engine-level test.
ENGINE_TEST="$ROOT/src/macos/scripts/test-engine.sh"
if [ -f "$ENGINE_TEST" ]; then
  echo "==> running engine test: $ENGINE_TEST"
  bash "$ENGINE_TEST"
else
  echo "==> no test-engine.sh present; skipping engine test"
fi

# 2) Bundle, plist, signature and architecture checks.
APP="$ROOT/dist-macos/JianFanConverter.app"
INFO="$APP/Contents/Info.plist"
EXEC="$APP/Contents/MacOS/JianFanConverter"

[ -d "$APP" ] || fail "missing app bundle: $APP"
[ -f "$INFO" ] || fail "missing Info.plist: $INFO"
[ -f "$EXEC" ] || fail "missing executable: $EXEC"

echo "==> plutil -lint"
plutil -lint "$INFO" || fail "Info.plist did not lint"

echo "==> codesign --verify --strict"
codesign --verify --strict "$APP" || fail "code signature verification failed"

echo "==> lipo -info"
LIPO_INFO="$(lipo -info "$EXEC")" || fail "lipo failed on $EXEC"
echo "    $LIPO_INFO"
case "$LIPO_INFO" in
  *arm64*) ;;
  *) fail "arm64 missing from $EXEC" ;;
esac
case "$LIPO_INFO" in
  *x86_64*) ;;
  *) fail "x86_64 missing from $EXEC" ;;
esac

# 3) No dynamic libraries, and the expected OpenCC asset counts.
echo "==> checking for stray dylibs"
DYLIB_FILES="$(find "$APP" -name '*.dylib' -type f)"
[ -z "$DYLIB_FILES" ] || fail "bundle contains .dylib: $DYLIB_FILES"

echo "==> checking embedded OpenCC assets"
RES_OPENCC="$APP/Contents/Resources/opencc"
[ -d "$RES_OPENCC" ] || fail "missing resources directory: $RES_OPENCC"

JSON_COUNT="$(find "$RES_OPENCC" -maxdepth 1 -name '*.json' -type f | wc -l | tr -d ' ')"
OCD2_COUNT="$(find "$RES_OPENCC" -maxdepth 1 -name '*.ocd2' -type f | wc -l | tr -d ' ')"
[ "$JSON_COUNT" -eq 10 ] || fail "expected 10 .json files in $RES_OPENCC, found $JSON_COUNT"
[ "$OCD2_COUNT" -eq 19 ] || fail "expected 19 .ocd2 files in $RES_OPENCC, found $OCD2_COUNT"
echo "    json: $JSON_COUNT, ocd2: $OCD2_COUNT"

# 4) Success.
echo "SMOKE OK"
