---
harness_version: v1.2
synced_at: 2026-04-27
source: https://github.com/tcp-software/ios-harnessing-hub
---

# Harness Version

<!--
  PURPOSE: Tracks which version of the ios-harnessing-hub shared rules are installed in this repo.
  DO NOT edit manually — this file is managed by the /sync-harness skill.
  UPDATE: Automatically updated when /sync-harness is run.
-->

## Installed Version

| Field | Value |
|-------|-------|
| Version | v1.2 |
| Synced at | 2026-04-27 |
| Source | https://github.com/tcp-software/ios-harnessing-hub |

## Synced Content

Only the following is sourced from the harness hub and should not be edited manually:

- `.claude/` — skills, agents, hooks, tools, settings.json
- `.harness/rules/` — iOS coding rules
- `.harness/BRANCHING.md` — branch naming and PR conventions
- `.harness/TEAM.md` — team ownership and reviewer assignments

The following are per-project and never touched by sync:
`.harness/CONTEXT.md`, `.harness/ARCHITECTURE.md`, `.harness/WORKFLOWS.md`,
`.harness/DEPENDENCIES.md`, `.harness/VERSIONING.md`, `CLAUDE.md`

To check for updates and sync to the latest version: `/harness-sync`

## Version History

| Version | Date | Notes |
|---------|------|-------|
| v1.0 | 2026-04-06 | Initial harness setup |
| v1.1 | 2026-04-27 | Adding agents and skills |
| v1.2 | 2026-04-27 | Swift LSP MCP (SwiftLens) — semantic code intelligence for all agents |
