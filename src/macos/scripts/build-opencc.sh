#!/usr/bin/env bash
#
# Build the universal (arm64 + x86_64) static OpenCC library used by the macOS
# app. The result is committed as vendor/opencc/macos/libopencc.a so that
# build-app.sh does not need the OpenCC source tree.
#
# Usage:
#   src/macos/scripts/build-opencc.sh
#   OPENCC_SRC=/path/to/OpenCC-1.4.2 src/macos/scripts/build-opencc.sh
#
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: build-opencc.sh must run on macOS (Darwin)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [ -n "${OPENCC_SRC:-}" ]; then
  SRC="$OPENCC_SRC"
else
  SRC="$ROOT/vendor/opencc-src"
fi

if [ ! -d "$SRC" ]; then
  echo "error: OpenCC source tree not found: $SRC" >&2
  echo "Set OPENCC_SRC to an OpenCC 1.4.2 checkout, or place it at:" >&2
  echo "  $ROOT/vendor/opencc-src" >&2
  echo "Get the source once with:" >&2
  echo "  git clone --branch ver.1.4.2 --depth 1 https://github.com/BYVoid/OpenCC.git \"$ROOT/vendor/opencc-src\"" >&2
  echo "(the source tree is gitignored; only maintainers rebuilding the" >&2
  echo " static library need it)." >&2
  exit 1
fi

command -v cmake >/dev/null 2>&1 || {
  echo "error: cmake not found; install it first (for example: brew install cmake)." >&2
  exit 1
}

BUILD_DIR="$ROOT/.build/opencc-macos"
OUT_LIB="$ROOT/vendor/opencc/macos/libopencc.a"
mkdir -p "$ROOT/vendor/opencc/macos"

echo "==> configuring OpenCC"
cmake -S "$SRC" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_OPENCC_JIEBA_PLUGIN=OFF \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DCMAKE_INSTALL_PREFIX=/usr/local

echo "==> building OpenCC"
cmake --build "$BUILD_DIR" --parallel

echo "==> locating static libraries"
# Use find -print -quit instead of a pipe to head so that pipefail does not
# trip on SIGPIPE, and so we never hardcode a marisa version path.
LIBOPENCC="$(find "$BUILD_DIR" -name 'libopencc.a' -type f -print -quit)"
LIBMARISA="$(find "$BUILD_DIR" -name 'libmarisa.a' -type f -print -quit)"

if [ -z "$LIBOPENCC" ] || [ ! -f "$LIBOPENCC" ]; then
  echo "error: libopencc.a not found under $BUILD_DIR" >&2
  exit 1
fi
if [ -z "$LIBMARISA" ] || [ ! -f "$LIBMARISA" ]; then
  echo "error: libmarisa.a not found under $BUILD_DIR" >&2
  exit 1
fi
echo "    libopencc: $LIBOPENCC"
echo "    libmarisa: $LIBMARISA"

echo "==> merging into a single static library"
rm -f "$OUT_LIB"
libtool -static -o "$OUT_LIB" "$LIBOPENCC" "$LIBMARISA"

echo "==> verifying architectures"
LIPO_INFO="$(lipo -info "$OUT_LIB")"
echo "    $LIPO_INFO"
case "$LIPO_INFO" in
  *arm64*) ;;
  *)
    echo "error: arm64 is missing from $OUT_LIB" >&2
    exit 1
    ;;
esac
case "$LIPO_INFO" in
  *x86_64*) ;;
  *)
    echo "error: x86_64 is missing from $OUT_LIB" >&2
    exit 1
    ;;
esac

echo "==> sha256"
SHASUM_VALUE="$(shasum -a 256 "$OUT_LIB" | awk '{print $1}')"
echo "    $SHASUM_VALUE  $OUT_LIB"
echo ""
echo "Record this hash in vendor/opencc/macos/BUILD.md."
