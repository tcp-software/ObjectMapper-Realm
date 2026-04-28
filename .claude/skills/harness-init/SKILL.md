---
name: harness-init
description: Initialize harness in a new repo (fresh) or update .claude/ from hub (update mode) — run /harness-init [--branch <branch>]
allowed-tools:
  - Bash
  - Read
  - Write
  - Agent
---

# Harness Init

Initialize the AI harness in this repository from the ios-harnessing-hub, or refresh `.claude/` if the harness is already present.

## Step 1: Parse Arguments

Check if a `--branch` argument was provided. Default to `main` if not.

```
/harness-init            → pulls from main
/harness-init --branch feature/xyz  → pulls from that branch
```

Store the resolved branch as `{branch}` for use in all subsequent steps.

## Step 2: Detect Mode

```bash
ls -d .claude .harness 2>/dev/null | wc -l
```

- **Both exist** (`.claude/` and `.harness/`) → **Update** mode — proceed to Step 3b
- **Either missing** → **Fresh init** mode — proceed to Step 3a (`.claude/` may already exist from bootstrap — that is fine)

## Step 3a: Fresh Init

Announce:
```
Initializing harness from ios-harnessing-hub@{branch}...
```

Download the hub archive and copy the full template:

```bash
mkdir -p /tmp/harness-init-extract
gh api repos/tcp-software/ios-harnessing-hub/tarball/{branch} \
  -H "Accept: application/vnd.github+json" \
  --output /tmp/harness-init.tar.gz
tar -xzf /tmp/harness-init.tar.gz -C /tmp/harness-init-extract --strip-components=1
cp -r /tmp/harness-init-extract/templates/repo-template/.claude ./
cp -r /tmp/harness-init-extract/templates/repo-template/.harness ./
cp /tmp/harness-init-extract/templates/repo-template/CLAUDE.md ./
cp /tmp/harness-init-extract/templates/repo-template/.mcp.json ./
rm -rf /tmp/harness-init.tar.gz /tmp/harness-init-extract
```

Proceed to Step 4.

## Step 3b: Update Mode

Announce:
```
Updating .claude/ from ios-harnessing-hub@{branch}...
```

Download the hub archive and replace only `.claude/`:

```bash
mkdir -p /tmp/harness-init-extract
gh api repos/tcp-software/ios-harnessing-hub/tarball/{branch} \
  -H "Accept: application/vnd.github+json" \
  --output /tmp/harness-init.tar.gz
tar -xzf /tmp/harness-init.tar.gz -C /tmp/harness-init-extract --strip-components=1
rm -rf .claude/
cp -r /tmp/harness-init-extract/templates/repo-template/.claude ./
cp /tmp/harness-init-extract/templates/repo-template/.mcp.json ./
rm -rf /tmp/harness-init.tar.gz /tmp/harness-init-extract
```

Proceed to Step 5 (update output).

## Step 4: Context Population (Fresh Init Only)

Announce:
```
✅ Harness initialized from ios-harnessing-hub@{branch}

Created:
  .claude/   — skills, agents, hooks, tools
  .harness/  — rules, context templates
  CLAUDE.md  — project instructions template

Analyzing project to populate .harness context files...
```

Delegate to the `harness-context-builder` agent. It will analyze the codebase and write:
- `.harness/CONTEXT.md`
- `.harness/ARCHITECTURE.md`
- `.harness/WORKFLOWS.md`
- `.harness/DEPENDENCIES.md`

Wait for the agent to complete before proceeding to Step 5.

## Step 5: Final Output

**Fresh init (after context population):**
```
✅ Harness ready.

Auto-populated from codebase analysis:
  .harness/CONTEXT.md
  .harness/ARCHITECTURE.md
  .harness/WORKFLOWS.md
  .harness/DEPENDENCIES.md

Review and correct if needed, then fill in the remaining files:
  □ .harness/BRANCHING.md  — merge strategy, reviewer assignment
  □ .harness/TEAM.md       — CODEOWNERS path
  □ CLAUDE.md              — build/test/lint commands under Quick Commands

Connect MCP servers (see mcp-config/setup.md in the hub):
  □ Jira MCP  — required for /start-task, /pr
  □ gh CLI authenticated  — required for /pr, /harness-sync
```

**Update output:**
```
✅ .claude/ updated from ios-harnessing-hub@{branch}

Replaced:
  .claude/   — skills, agents, hooks, tools
  .mcp.json  — MCP server configuration

Not touched:
  .harness/  (repo-owned — never overwritten)
  CLAUDE.md  (repo-owned — never overwritten)

Review the diff, then commit the changes to your branch.
```

## Error Handling

- `gh api` fails → warn: `⚠️ Could not reach ios-harnessing-hub. Check: gh auth status`
- `tar` extraction fails → warn: `⚠️ Failed to extract hub archive. Verify branch name: {branch}`
