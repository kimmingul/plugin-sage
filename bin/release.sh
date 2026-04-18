#!/usr/bin/env bash
# release.sh — cut a release of plugin-sage.
#
# Usage: bin/release.sh <version>
#   e.g. bin/release.sh 0.4.0
#
# Preconditions (checked by this script, fails loud if any are missing):
#   1. <version> is semver (X.Y.Z).
#   2. Working tree is clean (no staged or unstaged changes, no untracked plugin files).
#   3. CHANGELOG.md contains a "## [<version>] — <date>" section.
#   4. tests/validate-structure.sh passes.
#   5. `claude plugin validate .` passes.
#   6. bin/sync-principles.sh produces no diff (idempotent).
#
# Actions:
#   - Bumps .claude-plugin/plugin.json version to <version>.
#   - Commits with message "release: v<version> — <first line of CHANGELOG entry>".
#   - Creates annotated tag v<version> with the full CHANGELOG section body.
#
# Does NOT push. The user pushes manually after reviewing.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$PLUGIN_ROOT"
cd "$PLUGIN_ROOT"

die() { printf 'release: ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf 'release: %s\n' "$*"; }

# ---- Arg validation ------------------------------------------------------
VERSION="${1:-}"
[[ -n "$VERSION" ]] || die "usage: bin/release.sh <version>"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "version '$VERSION' is not semver X.Y.Z"

TAG="v$VERSION"
log "target version: $VERSION (tag: $TAG)"

# Refuse to re-tag
if git -C "$REPO_ROOT" rev-parse "$TAG" >/dev/null 2>&1; then
  die "tag $TAG already exists"
fi

# ---- Working-tree clean --------------------------------------------------
if ! git -C "$REPO_ROOT" diff-index --quiet HEAD -- plugin-sage/; then
  die "plugin-sage/ has uncommitted changes; commit or stash before releasing"
fi
untracked="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- plugin-sage/)"
[[ -z "$untracked" ]] || die "plugin-sage/ has untracked files:\n$untracked"

# ---- CHANGELOG contains the version entry --------------------------------
changelog_entry="$(awk -v v="## [$VERSION]" '
  index($0, v) == 1 { capture=1; print; next }
  capture && /^## \[/ { exit }
  capture { print }
' CHANGELOG.md)"

[[ -n "$changelog_entry" ]] \
    || die "CHANGELOG.md has no '## [$VERSION] — …' section; add one before releasing"

first_line="$(printf '%s\n' "$changelog_entry" | awk 'NR==2 && /./ {print; exit}' || true)"

# ---- Sanity checks -------------------------------------------------------
log "running tests/validate-structure.sh"
bash tests/validate-structure.sh >/dev/null

log "running claude plugin validate (if available)"
if command -v claude >/dev/null 2>&1; then
  claude plugin validate . >/dev/null \
      || die "claude plugin validate failed"
fi

log "checking sync-principles idempotency"
bash bin/sync-principles.sh >/dev/null
if ! git -C "$REPO_ROOT" diff --quiet -- plugin-sage/skills/; then
  die "sync-principles produced drift; fix and recommit before releasing"
fi

# ---- Bump plugin.json version -------------------------------------------
log "bumping plugin.json to $VERSION"
manifest=".claude-plugin/plugin.json"
tmp="$(mktemp)"
awk -v v="$VERSION" '
  /^  "version":/ { sub(/"[0-9.]+"/, "\"" v "\""); print; next }
  { print }
' "$manifest" > "$tmp"
mv "$tmp" "$manifest"

# ---- Commit + tag --------------------------------------------------------
commit_msg="release: v$VERSION"
if [[ -n "$first_line" ]]; then
  commit_msg="release: v$VERSION — $first_line"
fi

git -C "$REPO_ROOT" add plugin-sage/"$manifest"
git -C "$REPO_ROOT" commit -m "$commit_msg"

git -C "$REPO_ROOT" tag -a "$TAG" -m "plugin-sage $TAG

$changelog_entry"

log "tagged $TAG"
log "next step: review with 'git show $TAG', then push origin/main and origin/$TAG"
