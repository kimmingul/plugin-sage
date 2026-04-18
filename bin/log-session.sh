#!/usr/bin/env bash
# SessionStart hook: appends a single line to ~/.claude/plugin-sage-usage.log
# recording that plugin-sage was loaded in this session.
# Reads session metadata from stdin JSON (session_id, transcript_path, etc.).
# ALWAYS exits 0. Hook logs; it never interferes with the session.

set -u

LOG_DIR="${HOME}/.claude"
LOG_FILE="${LOG_DIR}/plugin-sage-usage.log"

# Ensure log directory exists; fail silently if we cannot create it.
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# Parse stdin JSON (may be absent or malformed — degrade gracefully).
INPUT="$(cat 2>/dev/null || true)"
SESSION_ID="unknown"
if command -v jq >/dev/null 2>&1 && [[ -n "$INPUT" ]]; then
  SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // .sessionId // "unknown"' 2>/dev/null || echo unknown)"
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s | %s | session_start\n' "$TIMESTAMP" "$SESSION_ID" >> "$LOG_FILE" 2>/dev/null || true

exit 0
