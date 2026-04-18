#!/usr/bin/env bash
# publish.sh — publish an existing tag to GitHub with a ZIP attachment.
#
# Usage: bin/publish.sh <version>
#   e.g. bin/publish.sh 0.5.0
#
# Preconditions:
#   1. Tag v<version> exists locally (create it first with bin/release.sh).
#   2. Remote "origin" exists and points to a GitHub repo.
#   3. gh CLI is installed and authenticated.
#   4. CHANGELOG.md has a "## [<version>]" section (used for release notes).
#
# Actions:
#   1. Push tag to origin (idempotent — silent if already pushed).
#   2. Generate ZIP from the tag via git archive:
#        /tmp/plugin-sage-v<version>.zip  (archive root is plugin-sage/)
#   3. Create GitHub release from the tag with the ZIP attached and the
#      CHANGELOG section as release notes. If the release already exists,
#      only the ZIP is re-uploaded (--clobber).
#
# Side effects:
#   - Public GitHub release visible immediately after success.
#   - ZIP file at /tmp/plugin-sage-v<version>.zip (auto-cleaned by OS).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$PLUGIN_ROOT"
cd "$PLUGIN_ROOT"

die() { printf 'publish: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'publish: %s\n' "$*"; }

# ---- Arg validation ------------------------------------------------------
VERSION="${1:-}"
[[ -n "$VERSION" ]] || die "usage: bin/publish.sh <version>"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "version '$VERSION' is not semver X.Y.Z"

TAG="v$VERSION"

# ---- Preconditions -------------------------------------------------------
git -C "$REPO_ROOT" rev-parse "$TAG" >/dev/null 2>&1 \
    || die "tag $TAG does not exist locally; create it first with bin/release.sh"

command -v gh >/dev/null 2>&1 \
    || die "gh CLI required; install from https://cli.github.com"
gh auth status >/dev/null 2>&1 \
    || die "gh CLI is not authenticated; run 'gh auth login'"

git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1 \
    || die "no 'origin' remote configured"

# ---- Extract CHANGELOG entry --------------------------------------------
changelog_entry="$(awk -v v="[$VERSION]" '
  index($0, "## " v) == 1 { capture=1; print; next }
  capture && /^## \[/ { exit }
  capture { print }
' "$PLUGIN_ROOT/CHANGELOG.md")"

[[ -n "$changelog_entry" ]] \
    || die "CHANGELOG.md has no '## [$VERSION]' section"

# ---- Push tag (idempotent) ----------------------------------------------
log "pushing tag $TAG to origin"
git -C "$REPO_ROOT" push origin "$TAG" 2>&1 \
    | grep -v '^Everything up-to-date' || true

# ---- Build ZIP ----------------------------------------------------------
ZIP_FILE="/tmp/plugin-sage-${TAG}.zip"
log "creating ZIP: $ZIP_FILE"
git -C "$REPO_ROOT" archive --format=zip --prefix=plugin-sage/ -o "$ZIP_FILE" "$TAG"
log "ZIP size: $(du -h "$ZIP_FILE" | cut -f1)"

# ---- Create or update GitHub release ------------------------------------
if gh release view "$TAG" >/dev/null 2>&1; then
  log "release $TAG already exists; re-uploading ZIP asset"
  gh release upload "$TAG" "$ZIP_FILE" --clobber
else
  log "creating GitHub release $TAG"
  notes_file="$(mktemp)"
  printf '%s\n' "$changelog_entry" > "$notes_file"
  gh release create "$TAG" "$ZIP_FILE" \
      --title "plugin-sage $TAG" \
      --notes-file "$notes_file"
  rm -f "$notes_file"
fi

repo_url="$(gh repo view --json url --jq .url 2>/dev/null || true)"
log "done: ${repo_url:+${repo_url}/releases/tag/}$TAG"
