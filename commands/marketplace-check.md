---
name: marketplace-check
description: Run IMMEDIATELY BEFORE uploading a plugin to Claude.ai Marketplace or organization settings. Runs "claude plugin validate" and five supplementary checks (kebab-case, reserved prefixes, strict-mode conflicts, version mismatch, relative sources). Ends with a parse-ready READY_TO_UPLOAD / BLOCKED status line.
argument-hint: "[plugin-path]"
allowed-tools: Task, Bash
---

Validate the plugin at `$1` (or the current working directory) for marketplace upload readiness.

**Step 1:** Run `claude plugin validate "$1"` via the Bash tool. Capture stdout, stderr, and the exit code. If the `claude` CLI is not available, capture the failure message and continue — the agent will still produce a supplementary-check report.

**Step 2:** Dispatch the `marketplace-validator` subagent. Pass as context:
- The plugin root path.
- The raw validator output from Step 1 (combined stdout/stderr).
- The validator exit code.

The agent reads the manifest files and produces a structured report covering the validator's findings plus the five supplementary checks.

**Step 3:** Surface the agent's full report unchanged. The final line is `READY_TO_UPLOAD` or `BLOCKED: N blocking issue(s)` — machine-parseable for CI. Do not edit or reformat it.

If BLOCKED, ask the user which blocking item to address first. Do not automatically apply fixes.
