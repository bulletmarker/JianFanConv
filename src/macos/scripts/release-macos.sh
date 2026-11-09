#!/usr/bin/env bash
#
# Attach the macOS build to an existing JianFanConverter release.
#
# Release model B: each host builds and uploads its own artifact.
#   1. On Windows: release.ps1 creates the tag, the Gitee release (with the
#      Windows zip) and the GitHub release.
#   2. On macOS: this script builds the universal .app, zips it and uploads the
#      mac zip to the same Gitee + GitHub release.
#
# Usage:
#   src/macos/scripts/release-macos.sh --version 1.2.0
#   src/macos/scripts/release-macos.sh            (uses the newest git tag)
#
# Requirements: macOS, python3 (ships with Xcode Command Line Tools),
# GITEE_TOKEN in the environment, and gh for the GitHub attachment.

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: release-macos.sh must run on macOS (Darwin)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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
  VERSION="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
  VERSION="${VERSION#v}"
fi

if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: version must look like 1.2.3 (got '$VERSION')" >&2
  exit 1
fi

TAG="v$VERSION"
ZIP="$ROOT/dist-macos/JianFanConverter-v$VERSION-macos-universal.zip"

step() { echo; echo "== $1"; }
die() { echo "error: $1" >&2; exit 1; }

# --- pre-flight ------------------------------------------------------------
step "pre-flight"
if ! git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag $TAG not found locally; fetching tags"
  git -C "$ROOT" fetch --tags origin
fi
git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
  || die "tag $TAG does not exist (run release.ps1 on Windows first)"

TAG_SHA="$(git -C "$ROOT" rev-parse "$TAG^{commit}")"
HEAD_SHA="$(git -C "$ROOT" rev-parse HEAD)"
echo "tag:    $TAG ($TAG_SHA)"
echo "commit: $HEAD_SHA"

if [ "$TAG_SHA" != "$HEAD_SHA" ]; then
  die "HEAD is not at $TAG; check out the release commit first (git checkout $TAG)"
fi
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
  die "worktree is not clean; commit or stash first"
fi

# --- build -----------------------------------------------------------------
step "build"
bash "$ROOT/src/macos/scripts/build-app.sh" --version "$VERSION"
[ -f "$ZIP" ] || die "missing zip: $ZIP"

SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "zip:    $ZIP"
echo "sha256: $SHA256"

# --- Gitee -----------------------------------------------------------------
step "gitee: attach $(basename "$ZIP")"
TOKEN="${GITEE_TOKEN:-}"
[ -n "$TOKEN" ] || die "GITEE_TOKEN is not set"
command -v python3 >/dev/null 2>&1 \
  || die "python3 is required (installed with Xcode Command Line Tools)"

ORIGIN_URL="$(git -C "$ROOT" remote get-url origin)"
case "$ORIGIN_URL" in
  *://*) REPO_PATH="${ORIGIN_URL#*://}"; REPO_PATH="${REPO_PATH#*/}" ;;
  *@*:*) REPO_PATH="${ORIGIN_URL#*:}" ;;
  *) REPO_PATH="$ORIGIN_URL" ;;
esac
REPO_PATH="${REPO_PATH%.git}"
OWNER="${REPO_PATH%%/*}"
REPO="${REPO_PATH#*/}"
[ -n "$OWNER" ] && [ -n "$REPO" ] || die "cannot parse Gitee owner/repo from $ORIGIN_URL"

API="https://gitee.com/api/v5/repos/$OWNER/$REPO"
echo "repo:   $OWNER/$REPO"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

RELEASE_JSON="$TMP_DIR/release.json"
curl -sS "$API/releases/tags/$TAG" -o "$RELEASE_JSON"
RELEASE_ID="$(python3 - "$RELEASE_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
print(data["id"] if data else "")
PY
)"
[ -n "$RELEASE_ID" ] || die "Gitee release for $TAG not found (run release.ps1 on Windows first)"

ZIP_NAME="$(basename "$ZIP")"
ASSETS_JSON="$TMP_DIR/assets.json"
read_attached() {
  python3 - "$ASSETS_JSON" "$ZIP_NAME" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    assets = json.load(handle) or []
print("yes" if any(item.get("name") == sys.argv[2] for item in assets) else "")
PY
}

curl -sS "$API/releases/$RELEASE_ID/attach_files" -o "$ASSETS_JSON"
if [ "$(read_attached)" = "yes" ]; then
  echo "attachment already present: $ZIP_NAME"
else
  curl -sS -X POST \
    -F "access_token=$TOKEN" \
    -F "file=@$ZIP" \
    "$API/releases/$RELEASE_ID/attach_files" >/dev/null
  curl -sS "$API/releases/$RELEASE_ID/attach_files" -o "$ASSETS_JSON"
  [ "$(read_attached)" = "yes" ] || die "Gitee attachment upload could not be confirmed"
  echo "attachment uploaded: $ZIP_NAME"
fi
echo "gitee release: https://gitee.com/$OWNER/$REPO/releases/tag/$TAG"

# --- GitHub ----------------------------------------------------------------
step "github: attach $(basename "$ZIP")"
GITHUB_URL="$(git -C "$ROOT" remote get-url github 2>/dev/null || true)"
if [ -z "$GITHUB_URL" ]; then
  echo "WARNING: no github remote, skipping GitHub release"
elif ! command -v gh >/dev/null 2>&1; then
  echo "WARNING: gh not found, skipping GitHub release"
else
  case "$GITHUB_URL" in
    *://*) GH_PATH="${GITHUB_URL#*://}"; GH_PATH="${GH_PATH#*/}" ;;
    *@*:*) GH_PATH="${GITHUB_URL#*:}" ;;
    *) GH_PATH="$GITHUB_URL" ;;
  esac
  GH_PATH="${GH_PATH%.git}"
  if ! gh release view "$TAG" --repo "$GH_PATH" >/dev/null 2>&1; then
    die "GitHub release $TAG not found; wait for the mirror workflow or run: gh workflow run sync-from-gitee.yml --repo $GH_PATH"
  fi
  gh release upload "$TAG" "$ZIP" --repo "$GH_PATH" --clobber
  echo "github release: https://github.com/$GH_PATH/releases/tag/$TAG"
fi

# --- summary ---------------------------------------------------------------
step "done"
echo "version: $VERSION"
echo "commit : $HEAD_SHA"
echo "zip    : $ZIP"
echo "sha256 : $SHA256"
echo ""
echo "If the release notes list SHA256 values, add the macOS hash above."
