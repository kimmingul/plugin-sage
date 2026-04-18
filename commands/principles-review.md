---
name: principles-review
description: Run AFTER significant plugin changes and BEFORE publishing. Audits a plugin against the 10 harness principles and reports FAIL/WARN findings with file:line evidence. Does not apply fixes.
argument-hint: "[plugin-path]"
allowed-tools: Task
---

Review the plugin at `$1` (or the current working directory if no argument is given) against the 10 harness principles.

Dispatch the `principle-reviewer` subagent with the plugin root. The agent is read-only; it reports findings with file:line evidence but does not apply fixes.

Surface the agent's structured report unchanged. Do not summarize or reformat.

After the report, ask the user which FAIL/WARN items (if any) to address. Apply changes only after the user names specific items.
