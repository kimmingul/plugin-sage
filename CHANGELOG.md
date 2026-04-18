# Changelog

All notable changes to plugin-sage.

This project follows [Semantic Versioning](https://semver.org/).

## [0.6.0] — 2026-04-19

### Added

- **GitHub Actions CI.** `.github/workflows/ci.yml` runs `tests/validate-structure.sh` on every pull request to `main` and every push to `main`. Ubuntu runner, `jq` installed, no external services required. This replaces the pre-standalone umbrella CI workflow that was lost during the v0.5 topology change.
- **CI status badge in README.** Top of README now displays build status from the `ci.yml` workflow, linking to the Actions dashboard.

### Changed

- **`tests/validate-structure.sh` Task 14** now actively requires `.github/workflows/ci.yml` (was an umbrella-path check that silently skipped in standalone mode).

### Known limitations (carried from v0.5)

- Skills are English-only.
- `claude plugin validate` in CI is not configured — requires installing the CLI in the runner, deferred to v0.7. Task 13's graceful-skip branch handles CLI absence locally.
- Drift check against the source doc is not configured in CI — the source doc lives outside this repo. Deferred.
- Claude.ai marketplace registration and CONTRIBUTING.md remain deferred.

## [0.5.0] — 2026-04-18

### Added

- **`bin/publish.sh`.** Publishes an existing tag to GitHub: pushes the tag (idempotent), generates a source ZIP via `git archive` at `/tmp/plugin-sage-v<version>.zip` with `plugin-sage/` as archive root, and creates a GitHub Release attaching the ZIP. Uses the `## [<version>]` CHANGELOG section as release notes. Re-running on an already-published release re-uploads the ZIP (`--clobber`) without duplicating the release.
- **`.gitignore`.** Excludes `.DS_Store`, `*.log`, `.env`, `.env.local` — prevents macOS Finder metadata from leaking into distribution ZIPs.

### Fixed

- **`bin/release.sh`** now uses `PLUGIN_ROOT` as the git repo root (was `PLUGIN_ROOT/..`, which assumed the old umbrella structure). Standalone repo is the supported topology going forward.
- **`tests/validate-structure.sh` Task 6 idempotency check** now runs at the plugin-sage git root. Previously it silently took the "skipped — not in a git repo" branch in standalone mode, so idempotency was not actually verified on recent releases.

### Retroactive

- GitHub Release for v0.4.0 was created with a source ZIP attached.

### Known limitations (carried from v0.4)

- Skills are English-only.
- LLM-driven self principle-review remains manual at release; deterministic subset is automated in the test harness.
- GitHub Actions CI for plugin-sage is not configured (lost with the umbrella transition). Local `tests/validate-structure.sh` is the current gate.
- Claude.ai marketplace registration and CONTRIBUTING.md remain deferred.

## [0.4.0] — 2026-04-18

### Added

- **LICENSE file.** MIT, copyright Min-Gul Kim 2026.
- **Extended README.** New "Usage examples" section (abbreviated outputs for each of the three agents) and "Troubleshooting" section (three known degradation paths). CHANGELOG.md is now linked from the README.
- **`bin/release.sh`.** Versioned release automation. Validates semver, working-tree cleanliness, CHANGELOG presence, `validate-structure.sh`, `claude plugin validate`, and sync-principles idempotency before bumping plugin.json, committing, and creating an annotated tag. Never runs `git push` — that remains a deliberate manual step.

### Known limitations (carried from v0.3)

- Skills are English-only.
- LLM-driven self principle-review remains manual at release; deterministic subset is automated in the test harness.
- Actual GitHub push and Claude.ai marketplace registration are deferred to v0.5 (require explicit user authorization at push time).
- CONTRIBUTING.md deferred to v0.5.

## [0.3.0] — 2026-04-18

### Added

- **SessionStart usage logging hook (P10 completion).** New `bin/log-session.sh` appends one line per Claude Code session to `~/.claude/plugin-sage-usage.log`. Format: `ISO-8601 timestamp | session_id | session_start`. Always exits 0; degrades gracefully if `jq` or the home directory is unavailable.
- **Deterministic principle checks in the test harness.** `validate-structure.sh` now blocks regressions on four catalog violations: description length (>400 chars → FAIL, P1/P5), empty description (P5), non-kebab-case or reserved-prefix names in agent/skill/command frontmatter and in `plugin.json`/`marketplace.json` (P10), and `"type": "prompt"` hooks (P4). Runs on every CI build.

### Fixed

- **Missing `name:` frontmatter in commands.** The new P10 check surfaced that `commands/principles-review.md` and `commands/marketplace-check.md` lacked `name:` fields. Added them explicitly.

### Known limitations (carried from v0.2)

- Skills are English-only.
- LLM-driven self principle-review remains manual at release; deterministic subset now automated.
- Automated release script (`bin/release.sh`) deferred to v0.4.
- External distribution prep (LICENSE polish, public GitHub, marketplace registration) deferred to v0.4.

## [0.2.0] — 2026-04-18

### Fixed

- **§4.9 slicer regex** hardened against hypothetical `### 4.10` subsection. A secondary terminator (`^## `) guarantees the slice never leaks past §4's boundary.

### Changed

- **`principle-reviewer` agent (P3 remediation):** added a "Common violations we see most often" section that front-loads the 10 most frequent failure patterns (description overrun, non-kebab-case names, reserved prefixes, Bash in reviewers, railroading hooks, LLM-gated hooks, oversized SKILL.md, undated citations, reconstruction).
- **Command descriptions (P5 remediation):** `/principles-review` and `/marketplace-check` now open with imperative triggers (`Run AFTER …`, `Run IMMEDIATELY BEFORE …`) instead of descriptive phrasing, matching the trigger pattern Principle 5 prescribes.
- **`marketplace-validator` agent (P8 remediation):** `Bash` removed from tool list. The `claude plugin validate` invocation now happens in the `/marketplace-check` command itself (via its existing `allowed-tools: Task, Bash`), and the agent receives the validator output as input context. Generate/Evaluate separation is now structural, not instructional.

### Known limitations (carried from v0.1)

- Skills are English-only.
- Self principle-review is manual; automation is v0.3 scope.
- Automated release script (`bin/release.sh`) is v0.3 scope.
- Usage logging hook (Principle 10 reference) is v0.3 scope.

## [0.1.0] — 2026-04-18

### Added

- `harness-principles` Skill — 10 principles with per-principle reference files, generated from the source doc.
- `marketplace-publishing` Skill — schema, source types, strict mode, error messages, warnings, gotchas, pre-upload checklist.
- `principle-reviewer` agent — read-only reviewer, emits structured per-principle verdicts.
- `marketplace-validator` agent — wraps `claude plugin validate` with five supplementary checks and parse-ready status line.
- `component-classifier` agent — consultative advisor for Skill/Agent/Hook/Plugin decisions.
- `/principles-review` command — explicit invocation of the principle reviewer.
- `/marketplace-check` command — pre-upload gate with machine-readable last line.
- `post-edit-validate` hook — auto-runs `claude plugin validate` when manifests are edited; always exits 0.
- `bin/sync-principles.sh` — idempotent extractor from the source doc to Skill files.
- `tests/validate-structure.sh` — structural acceptance tests.
- `.github/workflows/sync-check.yml` — drift detection and structure validation on PRs.

### Known limitations

- Skills are English-only. Source doc has a Korean edition for reading.
- Self principle-review is manual for v0.1; automation is v0.2 scope.
- Automated release script (`bin/release.sh`) is v0.2 scope.

### Self-review findings (v0.1.0 dogfood, 0 FAIL / 3 WARN)

- **Principle 3 (Gotchas Over Generics) — WARN:** Agent prompts describe check criteria but do not front-load the most common violation patterns. Deferred to v0.2 — can be addressed with a "Common violations" section in `agents/principle-reviewer.md`.
- **Principle 5 (Description Is a Trigger) — WARN:** Command descriptions (`/principles-review`, `/marketplace-check`) are descriptive ("Use after …") rather than imperative ("Run before …"). Agent descriptions already satisfy the principle. Deferred to v0.2.
- **Principle 8 (Separate Generate & Evaluate) — WARN:** `marketplace-validator` has `Bash` in its tool list to run `claude plugin validate`. Write access is prevented by instruction, not by tool-list structure. A v0.2 refactor could split into a Bash-only runner + Read-only reporter.
