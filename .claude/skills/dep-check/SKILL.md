---
name: dep-check
description: Check Swift import dependencies against architecture layer boundaries
agent: dependency-checker
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Dependency Check

Verify that Swift imports in the current changeset comply with the project's architecture boundaries.

## Step 1: Read Architecture

Read `.harness/ARCHITECTURE.md` to understand the module layer structure before analyzing results.

## Step 2: Run Check

```bash
bash .claude/tools/dep-check.sh
```

## Step 3: Report

**BLOCK findings** — must resolve before merge:
- Cite the specific file, line, import, and which architecture boundary it violates
- State the correct pattern

**WARNING findings** — investigate:
- Unused imports: confirm whether intentional or accidental
