# plugin-sage

A wise advisor for Claude Code plugin authors.

## What it does

- **Principle review.** Audits your plugin against 10 harness principles (Thariq Shihipar, 2026-02).
- **Marketplace pre-upload validation.** Runs `claude plugin validate` plus five supplementary checks the validator misses.
- **Component classification.** Helps you decide: Skill, Agent, Hook, or Plugin?

## Installation

Local development (from a clone):

```bash
claude plugin install /path/to/plugin-sage
```

Once published to a git-based marketplace:

```bash
claude plugin install github:kimmingul/plugin-sage
```

## Quick start

| Action | How |
|--------|-----|
| Audit your plugin | `/principles-review [path]` |
| Pre-upload check | `/marketplace-check [path]` |
| Classify a new idea | Describe it to Claude; `component-classifier` activates on design questions |

All three agents activate on natural-language requests too ("review this plugin", "is this upload ready?", "should this be a Skill or an Agent?").

## Usage examples

### `/principles-review` — abbreviated output

```
## Principle Review: my-plugin

### Summary
7 PASS, 2 WARN, 1 FAIL

### Principle 1 — Progressive Disclosure: WARN
- skills/foo/SKILL.md:1-45 — description exceeds 3 lines
- Reason: longer descriptions get interpreted as trigger text; risks misfires
- Suggestion: compress to 1-line summary, push detail into body H2 sections

### Principle 4 — Deterministic Where Possible: FAIL
- hooks/pre-commit.json:12 — LLM call inside PreToolUse matcher
- Reason: commit gating must be deterministic; LLM retries produce non-identical outcomes
- Suggestion: replace with a bash/regex script; keep LLM work in a separate agent

...

_This review uses principles as of 2026-04-18. Verify with the latest source doc if in doubt._
```

### `/marketplace-check` — pre-upload gate

```
## Marketplace Pre-Upload Check: my-plugin

### claude plugin validate
✔ Validation passed

### Supplementary checks
- [A kebab-case]      PASS — all names match /^[a-z0-9]+(-[a-z0-9]+)*$/
- [B reserved-prefix] PASS — no reserved prefixes
- [C strict-conflict] PASS — strict=true (default), plugin.json declares no component arrays
- [D version-match]   PASS — marketplace.json has no version (plugin.json authoritative)
- [E relative-source] WARN — relative source "./" works for git-based marketplaces only; confirm distribution medium

### Blocking issues
None

READY_TO_UPLOAD
```

The last line is either `READY_TO_UPLOAD` or `BLOCKED: N blocking issue(s)` — parse-ready for CI integration.

### `component-classifier` — design consultation

```
## Recommendation: Agent (+ supporting Skill)

Your need: "analyze PR diffs for security issues"

Agent is right for the main work because:
- Fresh context lets the agent read many files without polluting the session
- Output is a report (not code edits to your files)

Supporting Skill for:
- The list of security patterns — this is reusable knowledge

Alternative considered — just a Hook:
- Rejected because detection requires judgment; regex would miss context-dependent issues
- Keep determinism for the simpler parts: a Hook can gate "PR has Security Agent review attached"

Trade-off:
- Agent is slower but more accurate than a regex Hook.

You decide. If you pick the alternative, the trade-off flips to speed over accuracy.
```

## What this plugin is NOT

- **Not a scaffolder.** For new plugins use [`plugin-dev:create-plugin`](https://github.com/anthropics/claude-plugins) (Anthropic official).
- **Not a fixer.** `plugin-sage` reports; you decide what to change. (Principle 6: Avoid Railroading.)
- **Not bilingual.** All plugin artifacts are English. The source principle doc has a Korean edition for reading; the plugin itself does not ship Korean content.
- **Not a replacement** for `claude plugin validate`. `plugin-sage` wraps that tool and adds the five publication rules the validator misses.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `/marketplace-check` reports `validator unavailable — CLI not found` | `claude` CLI not on PATH | Install/reinstall Claude Code CLI so that `claude` is callable from your shell. The five supplementary checks still run regardless. |
| `post-edit-validate` hook is silent even after editing `plugin.json` | `jq` not installed | Install `jq` (`brew install jq` / `apt install jq`). The hook degrades to a silent no-op when `jq` is missing. |
| `bin/sync-principles.sh` logs `Source doc not found … skipping sync` | The plugin is installed outside the umbrella repo | Expected behaviour for standalone installs. Generated skills are already committed; the sync is a build step only for contributors editing the source doc. |
| `/principles-review` reports an unexpected FAIL on your plugin | The 10 principles document evolves. Your plugin may be fine; a principle was sharpened. | Check `CHANGELOG.md` for the date of the last source-doc update. Review the specific principle's `references/NN-*.md` in this plugin for the current definition. |

## The 10 principles — source of truth

Skills are generated from [`claude-plugin-harness-best-practices-en.md`](../claude-plugin-harness-best-practices-en.md) by [`bin/sync-principles.sh`](bin/sync-principles.sh). See that file for rationale, examples, and cross-references.

To re-sync after editing the source doc:

```bash
bash plugin-sage/bin/sync-principles.sh
```

CI at the umbrella repo root blocks merges when the source doc and generated skills drift.

## Changelog

Version history: [CHANGELOG.md](CHANGELOG.md).

## Credits

Principles distilled from Thariq Shihipar's [Seeing Like an Agent](https://x.com/trq212/status/2027463795355095314) and How We Use Skills (Anthropic, 2026-02).

## License

MIT — see [LICENSE](LICENSE).
