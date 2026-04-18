#!/usr/bin/env bash
# PostToolUse hook script.
# - Reads the tool invocation JSON from stdin.
# - If the edited file is a .claude-plugin/(plugin|marketplace).json,
#   runs `claude plugin validate` on its plugin root and reports.
# - Otherwise, silently no-ops.
# - ALWAYS exits 0. The hook's role is to report, not to block.

set -u

noop_exit() {
  # A quiet exit 0 so unrelated edits don't produce hook chatter.
  exit 0
}

# 1. Read stdin JSON. If jq is absent, no-op gracefully.
if ! command -v jq >/dev/null 2>&1; then
  noop_exit
fi

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && noop_exit

# 2. Extract the edited file path. Different edit tools use slightly
#    different fields; try the common ones.
FILE_PATH="$(printf '%s' "$INPUT" | jq -r '
  .tool_input.file_path
  // .tool_input.filePath
  // .tool_input.path
  // empty
' 2>/dev/null)"

[[ -z "$FILE_PATH" ]] && noop_exit

# 3. Filter: only run when the edited file is a plugin manifest.
case "$FILE_PATH" in
  */.claude-plugin/plugin.json|*/.claude-plugin/marketplace.json)
    : # proceed
    ;;
  *)
    noop_exit
    ;;
esac

# 4. Walk up to the plugin root (parent of .claude-plugin/).
PLUGIN_ROOT="$(dirname "$(dirname "$FILE_PATH")")"

# 5. If `claude` CLI is absent, report once and exit 0.
if ! command -v claude >/dev/null 2>&1; then
  printf '[plugin-sage] validate skipped — claude CLI not found\n'
  exit 0
fi

# 6. Run validate, capture output, never fail the hook.
if OUTPUT="$(claude plugin validate "$PLUGIN_ROOT" 2>&1)"; then
  printf '[plugin-sage] ✓ %s — validate passed\n' "$FILE_PATH"
else
  printf '[plugin-sage] ✗ %s — validation reported issues:\n' "$FILE_PATH"
  printf '%s\n' "$OUTPUT"
  printf '\nRun /marketplace-check for the full gotchas audit.\n'
fi

exit 0
