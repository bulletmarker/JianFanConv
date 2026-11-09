#!/usr/bin/env bash
#
# Compile JianFanConverter for arm64 and x86_64, assemble a .app bundle,
# ad-hoc sign it and produce a distributable zip.
#
# Usage:
#   src/macos/scripts/build-app.sh
#   src/macos/scripts/build-app.sh --version 1.2.0
#
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: build-app.sh must run on macOS (Darwin)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MACOS="$ROOT/src/macos"
OUT="$ROOT/dist-macos"
BUILD="$ROOT/.build/macos"
LIBDIR="$ROOT/vendor/opencc/macos"

# --- version ---------------------------------------------------------------
VERSION=""
if [ "${1:-}" = "--version" ]; then
  if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
    echo "error: --version requires a value such as 1.2.3" >&2
    exit 1
  fi
  VERSION="$2"
elif [ "$#" -gt 0 ]; then
  echo "error: unknown argument: $1" >&2
  echo "usage: $0 [--version X.Y.Z]" >&2
  exit 1
else
  if git -C "$ROOT" describe --tags --abbrev=0 >/dev/null 2>&1; then
    VERSION="$(git -C "$ROOT" describe --tags --abbrev=0)"
  fi
fi
VERSION="${VERSION#v}"
if [ -z "$VERSION" ]; then
  VERSION="0.0.0"
fi
echo "==> version: $VERSION"

# --- preconditions ---------------------------------------------------------
if [ ! -f "$LIBDIR/libopencc.a" ]; then
  echo "error: missing static library: $LIBDIR/libopencc.a" >&2
  echo "Build it once on a Mac before packaging the app:" >&2
  echo "  OPENCC_SRC=/path/to/OpenCC-1.4.2 src/macos/scripts/build-opencc.sh" >&2
  exit 1
fi

if [ ! -d "$MACOS/Sources/JianFanConv" ]; then
  echo "error: missing Swift sources: $MACOS/Sources/JianFanConv" >&2
  exit 1
fi

SWIFT_SOURCES="$(find "$MACOS/Sources/JianFanConv" -name '*.swift' -type f)"
if [ -z "$SWIFT_SOURCES" ]; then
  echo "error: no .swift files found under $MACOS/Sources/JianFanConv" >&2
  exit 1
fi

APP="$OUT/JianFanConverter.app"
EXEC="$APP/Contents/MacOS/JianFanConverter"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT"

# --- compile ---------------------------------------------------------------
echo "==> compiling universal binary"
for ARCH in arm64 x86_64; do
  echo "    - $ARCH"
  mkdir -p "$BUILD/$ARCH"
  # shellcheck disable=SC2086
  swiftc -O -whole-module-optimization -parse-as-library \
    -target "$ARCH-apple-macos14.0" \
    -import-objc-header "$MACOS/Sources/COpenCC/Bridging.h" \
    -I "$MACOS/Sources/COpenCC" \
    -L "$LIBDIR" -lopencc -lc++ \
    -framework SwiftUI -framework AppKit \
    -o "$BUILD/$ARCH/JianFanConverter" \
    $SWIFT_SOURCES
done

echo "==> merging architectures"
lipo -create \
  "$BUILD/arm64/JianFanConverter" \
  "$BUILD/x86_64/JianFanConverter" \
  -output "$EXEC"
chmod +x "$EXEC"

# --- Info.plist ------------------------------------------------------------
echo "==> assembling bundle metadata"
cp "$MACOS/Info.plist" "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"

# --- OpenCC data (configs + dictionaries, never the Windows DLL) -----------
echo "==> copying OpenCC assets"
RES_OPENCC="$APP/Contents/Resources/opencc"
mkdir -p "$RES_OPENCC"
shopt -s nullglob
for f in "$ROOT/vendor/opencc"/*.json "$ROOT/vendor/opencc"/*.ocd2; do
  cp "$f" "$RES_OPENCC/"
done
shopt -u nullglob

# --- licenses --------------------------------------------------------------
echo "==> writing licenses"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE.txt"
{
  echo "JianFanConverter third-party notices"
  echo "===================================="
  echo ""
  echo "The application code is licensed under the MIT License (see LICENSE.txt)."
  echo "The bundled OpenCC engine and dictionaries are licensed under the Apache"
  echo "License 2.0. The upstream license and NOTICE follow verbatim."
  echo ""
  echo "----- vendor/opencc/LICENSE -----"
  echo ""
  cat "$ROOT/vendor/opencc/LICENSE"
  echo ""
  echo "----- vendor/opencc/NOTICE.txt -----"
  echo ""
  cat "$ROOT/vendor/opencc/NOTICE.txt"
} > "$APP/Contents/Resources/THIRD-PARTY-NOTICES.txt"

# --- app icon --------------------------------------------------------------
ICON_PNG="$MACOS/Resources/AppIcon.png"
if [ -f "$ICON_PNG" ]; then
  if command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
    echo "==> generating AppIcon.icns"
    ICONSET="$BUILD/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    sips -z 16 16 "$ICON_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
  else
    echo "warning: sips/iconutil not found; skipping .icns generation" >&2
  fi
else
  echo "warning: $ICON_PNG not found; skipping .icns generation" >&2
fi

# --- sign ------------------------------------------------------------------
echo "==> signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

# --- verify bundle ---------------------------------------------------------
echo "==> verifying bundle"

MACHO_LINES="$(find "$APP/Contents/MacOS" -type f -exec file {} \;)"
MACHO_COUNT="$(printf '%s\n' "$MACHO_LINES" | grep -c 'Mach-O' || true)"
if [ "$MACHO_COUNT" -ne 1 ]; then
  echo "error: expected exactly one Mach-O under Contents/MacOS, found $MACHO_COUNT" >&2
  exit 1
fi

DYLIB_FILES="$(find "$APP" -name '*.dylib' -type f)"
if [ -n "$DYLIB_FILES" ]; then
  echo "error: bundle must not contain any .dylib:" >&2
  echo "$DYLIB_FILES" >&2
  exit 1
fi

LIPO_INFO="$(lipo -info "$EXEC")"
echo "    $LIPO_INFO"
case "$LIPO_INFO" in
  *arm64*) ;;
  *)
    echo "error: arm64 missing from $EXEC" >&2
    exit 1
    ;;
esac
case "$LIPO_INFO" in
  *x86_64*) ;;
  *)
    echo "error: x86_64 missing from $EXEC" >&2
    exit 1
    ;;
esac

# --- package ---------------------------------------------------------------
echo "==> packaging zip"
ZIP="$OUT/JianFanConverter-v$VERSION-macos-universal.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# --- summary ---------------------------------------------------------------
ARCHS="$(lipo -archs "$EXEC")"
BUNDLE_SIZE="$(du -sh "$APP" | awk '{print $1}')"
echo ""
echo "==> done"
echo "    version: $VERSION"
echo "    archs:   $ARCHS"
echo "    bundle:  $APP"
echo "    size:    $BUNDLE_SIZE"
echo "    zip:     $ZIP"
echo "    sha256:  $(shasum -a 256 "$ZIP" | awk '{print $1}')"
