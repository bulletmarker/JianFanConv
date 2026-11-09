#!/usr/bin/env bash
#
# Compiles and runs the OpenCC engine smoke test.
# macOS only: it needs swiftc and the vendored libopencc.a.
#
# Usage:
#   src/macos/scripts/test-engine.sh [<opencc-assets-dir>]
#
# The optional argument overrides the directory that holds the OpenCC .json
# configs and .ocd2 dictionaries (defaults to vendor/opencc).

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "test-engine.sh only runs on macOS (uname -s reported '$(uname -s)')." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SOURCES_DIR="$ROOT/src/macos/Sources/JianFanConv/Engine"
BRIDGING_HEADER="$ROOT/src/macos/Sources/COpenCC/Bridging.h"
INCLUDE_DIR="$ROOT/src/macos/Sources/COpenCC"
SMOKE_MAIN="$ROOT/src/macos/Tests/EngineSmoke/main.swift"
BUILD_DIR="$ROOT/src/macos/.build-engine-smoke"
BINARY="$BUILD_DIR/engine-smoke"
OPENCC_LIB_DIR="$ROOT/vendor/opencc/macos"
OPENCC_DIR="${1:-$ROOT/vendor/opencc}"

if [[ ! -f "$BRIDGING_HEADER" ]]; then
    echo "Bridging header not found: $BRIDGING_HEADER" >&2
    exit 1
fi

if [[ ! -f "$SMOKE_MAIN" ]]; then
    echo "Smoke test source not found: $SMOKE_MAIN" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"

SWIFT_FILES=()
while IFS= read -r file; do
    SWIFT_FILES+=("$file")
done < <(find "$SOURCES_DIR" -name '*.swift' -type f | sort)
SWIFT_FILES+=("$SMOKE_MAIN")

# main.swift holds top-level code, so -parse-as-library must NOT be passed.
# If the prebuilt static library exists, link against it explicitly.
LINK_ARGS=()
if [[ -f "$OPENCC_LIB_DIR/libopencc.a" ]]; then
    LINK_ARGS+=("-L" "$OPENCC_LIB_DIR" "-lopencc" "-lc++")
fi

TARGET="$(uname -m)-apple-macos14.0"

# ${LINK_ARGS[@]+...} keeps `set -u` happy on the bash 3.2 that ships with macOS.
swiftc -O \
    -target "$TARGET" \
    -import-objc-header "$BRIDGING_HEADER" \
    -I "$INCLUDE_DIR" \
    ${LINK_ARGS[@]+"${LINK_ARGS[@]}"} \
    -o "$BINARY" \
    "${SWIFT_FILES[@]}"

"$BINARY" "$OPENCC_DIR"
