---
name: harness-sync
description: Check hub skill version and optionally sync — run /harness-sync to update .claude/ to the latest release
agent: harness-checker
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Agent
---

# Harness Sync

<!--
  DUAL PURPOSE:
  1. Called as Step 0 from other skills — runs only the Version Check (Steps 1–3).
  2. Invoked directly via /harness-sync — runs the full flow including sync (Steps 4–6).
-->

---

## Version Check

> **When called from another skill:** execute Steps 1–3 only, then return to that skill's workflow.
> **When invoked directly via `/harness-sync`:** execute all steps.

### Step 1: Read Local Version

```bash
grep '^harness_version:' .harness/VERSIONING.md 2>/dev/null | awk '{print $2}'
```

If `.harness/VERSIONING.md` is not found:
- When called from another skill: skip silently, continue.
- When invoked directly: warn the developer and stop.
  ```
  ⚠️ .harness/VERSIONING.md not found. This repo has not adopted the harness versioning system yet.
  ```

### Step 2: Fetch Latest Release

```bash
gh api repos/tcp-software/ios-harnessing-hub/releases/latest --jq '.tag_name' 2>/dev/null
```

If this fails (not authenticated, no releases, network issue):
- When called from another skill: skip silently, continue.
- When invoked directly: warn and stop.
  ```
  ⚠️ Could not reach ios-harnessing-hub. Check: gh auth status
  ```

### Step 3: Compare Versions

If `local_version` equals `latest_version`:
- When called from another skill: no output, continue silently.
- When invoked directly: inform and stop.
  ```
  ✅ Skills are up to date (version: {version}). No action needed.
  ```

If `local_version` differs from `latest_version`:
- **Always** display this warning:
  ```
  ⚠️ Harness skills outdated — installed: {local_version}, latest: {latest_version}. Run /harness-sync to update.
  ```
- When called from another skill: display the warning, then return to that skill's workflow.
- When invoked directly: proceed to Step 4.

---

## Full Sync

> Only executed when this skill is invoked directly via `/harness-sync`.

### Step 4: Confirm with Developer

Present a summary and wait for explicit confirmation:

```
⚠️ Harness update available:
  Installed: {local_version}
  Latest:    {latest_version}

The following will be replaced:
  - .claude/          (skills, agents, hooks, tools, settings.json)
  - .harness/rules/   (iOS coding rules)
  - .harness/BRANCHING.md
  - .harness/TEAM.md

The following will NOT be touched:
  - .harness/CONTEXT.md, ARCHITECTURE.md, WORKFLOWS.md, DEPENDENCIES.md, VERSIONING.md
  - CLAUDE.md

Proceed with update? (yes/no)
```

If the developer says no, stop.

### Step 5: Download and Replace .claude/

```bash
TARBALL_URL=$(gh api repos/tcp-software/ios-harnessing-hub/releases/latest --jq '.tarball_url')
curl -sL "$TARBALL_URL" -o /tmp/harness-hub-latest.tar.gz
mkdir -p /tmp/harness-hub-extract
tar -xzf /tmp/harness-hub-latest.tar.gz -C /tmp/harness-hub-extract --strip-components=1
```

Replace the entire `.claude/` directory and shared `.harness/` files:

```bash
rm -rf .claude/
cp -r /tmp/harness-hub-extract/templates/repo-template/.claude/ ./
cp /tmp/harness-hub-extract/templates/repo-template/.mcp.json ./
rm -rf .harness/rules/
cp -r /tmp/harness-hub-extract/templates/repo-template/.harness/rules/ .harness/
cp /tmp/harness-hub-extract/templates/repo-template/.harness/BRANCHING.md .harness/BRANCHING.md
cp /tmp/harness-hub-extract/templates/repo-template/.harness/TEAM.md .harness/TEAM.md
rm -rf /tmp/harness-hub-latest.tar.gz /tmp/harness-hub-extract
```

### Step 6: Update VERSIONING.md

- Replace `harness_version:` in the frontmatter with the new version tag
- Replace `synced_at:` with today's date (YYYY-MM-DD)
- Update the **Installed Version** table (Version and Synced at rows)
- Append a new row to the **Version History** table

### Step 7: Present Result

```bash
git diff --stat
```

```
✅ Harness updated: {local_version} → {latest_version}

Replaced: .claude/, .mcp.json, .harness/rules/, .harness/BRANCHING.md, .harness/TEAM.md
Updated:  .harness/VERSIONING.md

Review the diff above, then commit the changes to your branch.
```
