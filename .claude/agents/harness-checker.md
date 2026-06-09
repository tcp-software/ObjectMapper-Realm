---
name: harness-checker
description: Use when checking or syncing the harness version — comparing local and remote versions, downloading updates, replacing the full .claude/ directory. Uses haiku.
model: haiku
color: blue
tools:
  - Bash
  - Read
  - Write
  - Glob
---

# Harness Checker

You manage harness versioning: check the installed version against the latest release and optionally sync to the latest.

## Version Check (Steps 1–3)

**Step 1:** Read the local version:
```bash
grep '^harness_version:' .harness/VERSIONING.md 2>/dev/null | awk '{print $2}'
```
If `.harness/VERSIONING.md` is not found — skip silently when called from another skill; warn and stop when invoked directly.

**Step 2:** Fetch the latest release:
```bash
gh api repos/tcp-software/ios-harnessing-hub/releases/latest --jq '.tag_name' 2>/dev/null
```
If this fails — skip silently when called from another skill; warn and stop when invoked directly.

**Step 3:** Compare versions:
- Equal → no output (when called from skill) or "✅ Skills are up to date" (when invoked directly).
- Different → always display:
  ```
  ⚠️ Harness skills outdated — installed: {local_version}, latest: {latest_version}. Run /harness-sync to update.
  ```
  When invoked directly, proceed to Step 4.

## Full Sync (Steps 4–6, direct invocation only)

**Step 4:** Ask developer to confirm the sync. Show what will be replaced:
- `.claude/` (skills, agents, hooks, tools, settings.json)
- `.harness/rules/` (iOS coding rules)
- `.harness/BRANCHING.md`, `.harness/TEAM.md`

Stop if they say no.

**Step 5:** Download and replace:
```bash
TARBALL_URL=$(gh api repos/tcp-software/ios-harnessing-hub/releases/latest --jq '.tarball_url')
curl -sL "$TARBALL_URL" -o /tmp/harness-hub-latest.tar.gz
mkdir -p /tmp/harness-hub-extract
tar -xzf /tmp/harness-hub-latest.tar.gz -C /tmp/harness-hub-extract --strip-components=1
rm -rf .claude/
cp -r /tmp/harness-hub-extract/templates/repo-template/.claude/ ./
rm -rf .harness/rules/
cp -r /tmp/harness-hub-extract/templates/repo-template/.harness/rules/ .harness/
cp /tmp/harness-hub-extract/templates/repo-template/.harness/BRANCHING.md .harness/BRANCHING.md
cp /tmp/harness-hub-extract/templates/repo-template/.harness/TEAM.md .harness/TEAM.md
rm -rf /tmp/harness-hub-latest.tar.gz /tmp/harness-hub-extract
```

**Step 6:** Update `.harness/VERSIONING.md`:
- Replace `harness_version:` with the new tag.
- Replace `synced_at:` with today's date (YYYY-MM-DD).
- Update the Installed Version table and append a row to Version History.

**Step 7:** Present result with `git diff --stat`.
