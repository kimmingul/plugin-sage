#!/usr/bin/env bash
# Structural acceptance tests for plugin-sage.
# Exits non-zero on first failure. Prints a checkmark per passed group.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*"; exit 1; }

echo "==> Task 1: skeleton"
[[ -f .claude-plugin/plugin.json ]]       || fail "plugin.json missing"
[[ -f .claude-plugin/marketplace.json ]]  || fail "marketplace.json missing"
[[ -f README.md ]]                        || fail "README.md missing"
[[ -f CHANGELOG.md ]]                     || fail "CHANGELOG.md missing"

# plugin.json required fields
grep -q '"name": "plugin-sage"'     .claude-plugin/plugin.json || fail "plugin.json name"
grep -q '"version"'                 .claude-plugin/plugin.json || fail "plugin.json version"
grep -q '"description"'             .claude-plugin/plugin.json || fail "plugin.json description"
grep -q '"author"'                  .claude-plugin/plugin.json || fail "plugin.json author"

# marketplace.json required fields (name pattern allows renaming for distribution)
grep -qE '"name": "[a-z0-9]+(-[a-z0-9]+)*"' .claude-plugin/marketplace.json || fail "marketplace.json name (kebab-case)"
grep -q '"owner"'                           .claude-plugin/marketplace.json || fail "marketplace.json owner"
grep -q '"plugins"'                         .claude-plugin/marketplace.json || fail "marketplace.json plugins"
grep -q '"name": "plugin-sage"'             .claude-plugin/marketplace.json || fail "marketplace.json plugins[].name references plugin-sage"
pass "skeleton files present and valid"

echo "==> Task 3: build pipeline skeleton"
[[ -x bin/sync-principles.sh ]]                                || fail "sync-principles.sh not executable"
[[ -f templates/harness-principles.SKILL.md.tmpl ]]            || fail "harness-principles template"
[[ -f templates/marketplace-publishing.SKILL.md.tmpl ]]        || fail "marketplace-publishing template"
pass "build pipeline skeleton in place"

echo "==> Task 4: harness-principles skill"
[[ -f skills/harness-principles/SKILL.md ]] || fail "SKILL.md missing"
head -6 skills/harness-principles/SKILL.md | grep -q "AUTO-GENERATED" || fail "no AUTO-GENERATED marker"
grep -q '^name: harness-principles$'        skills/harness-principles/SKILL.md || fail "SKILL.md name"
grep -q '^description: '                    skills/harness-principles/SKILL.md || fail "SKILL.md description"
count=$(ls skills/harness-principles/references/*.md 2>/dev/null | wc -l | tr -d ' ')
[[ "$count" = "10" ]] || fail "expected 10 principle references, got $count"
for f in skills/harness-principles/references/*.md; do
  head -1 "$f" | grep -q "AUTO-GENERATED" || fail "no AUTO-GENERATED marker in $f"
done
pass "harness-principles skill generated correctly"

echo "==> Task 5: marketplace-publishing skill"
[[ -f skills/marketplace-publishing/SKILL.md ]]                                 || fail "SKILL.md missing"
grep -q '^name: marketplace-publishing$' skills/marketplace-publishing/SKILL.md || fail "SKILL.md name"
for ref in schema source-types strict-mode error-messages warnings gotchas; do
  [[ -f "skills/marketplace-publishing/references/${ref}.md" ]] || fail "missing reference: ${ref}.md"
  head -1 "skills/marketplace-publishing/references/${ref}.md" | grep -q "AUTO-GENERATED" \
      || fail "no AUTO-GENERATED marker in ${ref}.md"
done
[[ -f skills/marketplace-publishing/checklists/pre-upload.md ]] || fail "pre-upload checklist missing"
checkcount=$(grep -c '^- \[ \]' skills/marketplace-publishing/checklists/pre-upload.md || true)
[[ "$checkcount" -ge 5 ]] || fail "pre-upload checklist too short ($checkcount items)"
pass "marketplace-publishing skill generated correctly"

echo "==> Task 6: sync idempotency"
# Re-run sync and check for drift (requires a git repo)
if git -C "$PLUGIN_ROOT/.." rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  bash "$PLUGIN_ROOT/bin/sync-principles.sh" >/dev/null
  if ! git -C "$PLUGIN_ROOT/.." diff --quiet -- plugin-sage/skills/; then
    fail "sync-principles.sh is not idempotent; second run produced changes"
  fi
  pass "sync is idempotent"
else
  pass "(skipped — not in a git repo)"
fi

echo "==> Task 7: principle-reviewer agent"
[[ -f agents/principle-reviewer.md ]] || fail "principle-reviewer.md missing"
grep -q '^name: principle-reviewer$' agents/principle-reviewer.md || fail "agent name"
grep -q '^tools: Read, Glob, Grep$'    agents/principle-reviewer.md || fail "read-only tools"
grep -q '^description: ' agents/principle-reviewer.md               || fail "agent description"
pass "principle-reviewer agent in place with read-only tools"

echo "==> Task 8: marketplace-validator agent"
[[ -f agents/marketplace-validator.md ]] || fail "marketplace-validator.md missing"
grep -q '^name: marketplace-validator$' agents/marketplace-validator.md || fail "agent name"
grep -q '^tools: Read, Grep$'            agents/marketplace-validator.md || fail "expected read-only tools"
grep -q 'READY_TO_UPLOAD'                agents/marketplace-validator.md || fail "missing parse-ready status"
grep -q 'BLOCKED: N blocking'            agents/marketplace-validator.md || fail "missing blocked status"
pass "marketplace-validator agent in place with parse-ready statuses"

echo "==> Task 9: component-classifier agent"
[[ -f agents/component-classifier.md ]] || fail "component-classifier.md missing"
grep -q '^name: component-classifier$'  agents/component-classifier.md || fail "agent name"
grep -q '^tools: Read$'                  agents/component-classifier.md || fail "expected pure-advisor tools"
grep -q 'You decide.$'                   agents/component-classifier.md || fail "missing 'You decide.' in output spec"
pass "component-classifier agent in place as read-only advisor"

echo "==> Task 10: /principles-review command"
[[ -f commands/principles-review.md ]]                       || fail "principles-review.md missing"
grep -q '^description: Run AFTER' commands/principles-review.md || fail "command description"
grep -q '^allowed-tools: Task$'          commands/principles-review.md || fail "command allowed-tools"
grep -q 'principle-reviewer'             commands/principles-review.md || fail "command dispatches agent"
pass "/principles-review command in place"

echo "==> Task 11: /marketplace-check command"
[[ -f commands/marketplace-check.md ]] || fail "marketplace-check.md missing"
grep -q '^description: Run IMMEDIATELY BEFORE' commands/marketplace-check.md || fail "command description"
grep -q '^allowed-tools: Task, Bash$' commands/marketplace-check.md || fail "command allowed-tools"
grep -q 'marketplace-validator' commands/marketplace-check.md || fail "command dispatches agent"
grep -q 'READY_TO_UPLOAD' commands/marketplace-check.md || fail "status line mentioned"
pass "/marketplace-check command in place"

echo "==> Task 12: hook"
[[ -f hooks/hooks.json ]] || fail "hooks.json missing"
grep -q '"PostToolUse"' hooks/hooks.json || fail "no PostToolUse event"
grep -q '"matcher": "Edit|Write|MultiEdit"' hooks/hooks.json || fail "matcher regex"
grep -q 'post-edit-validate.sh' hooks/hooks.json || fail "hook command path"
[[ -x bin/post-edit-validate.sh ]] || fail "post-edit-validate.sh not executable"
grep -q '^exit 0$' bin/post-edit-validate.sh || fail "script must always exit 0"
pass "hook configured and script executable"

echo "==> Task 13: self-validate"
if command -v claude >/dev/null 2>&1; then
  if claude plugin validate . >/tmp/plugin-sage-validate.log 2>&1; then
    pass "claude plugin validate . → OK"
  else
    cat /tmp/plugin-sage-validate.log
    fail "claude plugin validate . failed"
  fi
else
  pass "(skipped — claude CLI not found)"
fi

echo "==> Task 14: CI workflow"
if [[ -f "$PLUGIN_ROOT/../.github/workflows/sync-check.yml" ]]; then
  grep -q 'sync-principles.sh' "$PLUGIN_ROOT/../.github/workflows/sync-check.yml" || fail "workflow does not invoke sync-principles.sh"
  grep -q 'validate-structure.sh' "$PLUGIN_ROOT/../.github/workflows/sync-check.yml" || fail "workflow does not run validate-structure.sh"
  pass "CI workflow present at umbrella repo root"
else
  pass "(skipped — umbrella .github/ not present; this is OK for standalone plugin-sage)"
fi

echo "==> Task 15: README and CHANGELOG"
grep -q '^# plugin-sage$' README.md || fail "README.md heading"
grep -q 'What this plugin is NOT' README.md || fail "README missing 'NOT' section"
grep -q '^## Usage examples'       README.md || fail "README missing 'Usage examples' section"
grep -q '^## Troubleshooting'      README.md || fail "README missing 'Troubleshooting' section"
grep -q '^## \[0\.1\.0\]' CHANGELOG.md || fail "CHANGELOG missing 0.1.0 entry"
pass "README.md and CHANGELOG.md complete"

echo "==> v0.3 usage logging"
[[ -x bin/log-session.sh ]] || fail "log-session.sh not executable"
grep -q '"SessionStart"' hooks/hooks.json || fail "hooks.json missing SessionStart event"
grep -q 'log-session.sh' hooks/hooks.json || fail "hooks.json does not wire log-session.sh"
grep -q '^exit 0$' bin/log-session.sh || fail "log-session.sh must always exit 0"
grep -q 'plugin-sage-usage.log' bin/log-session.sh || fail "log-session.sh must use plugin-sage-usage.log"
pass "usage logging hook configured"

echo "==> v0.3 deterministic principle checks"

# Gather all files that carry frontmatter
frontmatter_files=()
for f in agents/*.md commands/*.md skills/*/SKILL.md; do
  [[ -f "$f" ]] && frontmatter_files+=("$f")
done

for f in "${frontmatter_files[@]}"; do
  # Extract description line (first line starting with "description:" inside the --- frontmatter)
  desc=$(awk '/^---$/{fm++; next} fm==1 && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f")

  # P5 — empty description
  [[ -n "$desc" ]] || fail "P5 empty description: $f"

  # P1/P5 — description overrun (over 400 chars)
  [[ "${#desc}" -le 400 ]] || fail "P1/P5 description overrun in $f (${#desc} chars, max 400)"

  # Extract name field; must be kebab-case
  name=$(awk '/^---$/{fm++; next} fm==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$f")
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "P10 non-kebab-case name in $f: '$name'"

  # P10 — reserved prefixes
  case "$name" in
    claude-*|anthropic-*|official-*)
      fail "P10 reserved prefix in $f: '$name'"
      ;;
  esac
done

# P10 — JSON name fields
for j in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  [[ -f "$j" ]] || continue
  # Extract top-level "name" value (simple quoted string match)
  jname=$(awk -F'"' '/^[[:space:]]*"name"[[:space:]]*:/{print $4; exit}' "$j")
  [[ "$jname" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "P10 non-kebab-case name in $j: '$jname'"
  case "$jname" in
    claude-*|anthropic-*|official-*)
      fail "P10 reserved prefix in $j: '$jname'"
      ;;
  esac
done

# P4 — no LLM-gated hooks (no "type": "prompt" in plugin hooks)
if [[ -f hooks/hooks.json ]]; then
  ! grep -q '"type"[[:space:]]*:[[:space:]]*"prompt"' hooks/hooks.json \
    || fail "P4 LLM-gated hook detected: remove type:prompt from hooks.json"
fi

pass "deterministic principle checks (P1/P4/P5/P10) pass"

echo "==> v0.4 LICENSE"
[[ -f LICENSE ]] || fail "LICENSE file missing"
grep -q '^MIT License$'            LICENSE || fail "LICENSE heading"
grep -q 'Copyright (c) 2026'        LICENSE || fail "LICENSE copyright year"
grep -q 'Min-Gul Kim'               LICENSE || fail "LICENSE copyright holder"
pass "LICENSE (MIT) in place"

echo "==> v0.4 release script"
[[ -x bin/release.sh ]]                              || fail "release.sh not executable"
grep -q 'claude plugin validate'   bin/release.sh    || fail "release.sh must run claude plugin validate"
grep -q 'sync-principles.sh'       bin/release.sh    || fail "release.sh must run sync-principles.sh"
grep -q 'CHANGELOG.md'             bin/release.sh    || fail "release.sh must read CHANGELOG.md"
grep -q 'tag -a'                   bin/release.sh    || fail "release.sh must create annotated tag"
! grep -q 'git push'               bin/release.sh    || fail "release.sh must NOT auto-push"
pass "release.sh is wired correctly"

echo
echo "All structural checks passed."
