---
name: mutation-test
description: Run mutation testing on changed Swift files to validate test quality
argument-hint: "Optional: path to specific Swift file"
agent: mutation-tester
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Mutation Test

Validate test quality by running mutation testing on changed Swift files.

## Step 1: Determine Target Files

If $ARGUMENTS contains a file path, use it.

Otherwise:
```bash
git diff main --name-only -- '*.swift'
```

## Step 2: Determine Build Mode

Check project type to decide between SPM mode and xcodebuild mode:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
ls "$PROJECT_ROOT/Package.swift" 2>/dev/null
ls "$PROJECT_ROOT"/*.xcworkspace 2>/dev/null
```

- If `Package.swift` exists and **no `.xcworkspace`** → SPM library: use `--package-path "$PROJECT_ROOT"` (no scheme needed)
- Otherwise → read `.harness/WORKFLOWS.md` for the test scheme name. If not found, ask the developer.

## Step 3: Determine Threshold

Based on the filename suffix, select the threshold. Thresholds are defined in the `mutation-tester` agent (`agents/mutation-tester.md`).

## Step 4: Run Mutation Testing

For each target Swift file:

**SPM library:**
```bash
bash .claude/tools/mutation-test.sh \
  --file {target-file} \
  --package-path {package-path} \
  --threshold {classified-threshold}
```

**Regular iOS project (xcodebuild):**
```bash
bash .claude/tools/mutation-test.sh \
  --file {target-file} \
  --scheme {scheme} \
  --threshold {classified-threshold}
```

## Step 5: Report

For each file:
- Present mutation score against its file-type threshold
- List surviving mutations with G/W/T scenarios that would kill them
- Flag files below their threshold and recommend specific additional tests
