---
name: crap-check
description: Analyze CRAP score for Swift functions in the current changeset
argument-hint: "Optional: path to specific Swift file"
agent: crap-analyzer
allowed-tools:
  - Bash
  - Read
  - Glob
---

# CRAP Check

Analyze the CRAP score (CC × (1 - coverage)²) for changed Swift files and report functions that require DECRAP.

## Step 1: Identify Target Files

If $ARGUMENTS contains a file path, use it.

Otherwise, get changed Swift files:
```bash
git diff main --name-only -- '*.swift'
```

## Step 2: Ensure Coverage Data Exists

Check for a recent `.xcresult`:
```bash
ls -t *.xcresult build.xcresult 2>/dev/null | head -1
```

If not found: instruct the developer to run tests first:
```bash
xcodebuild test -scheme {SCHEME} -enableCodeCoverage YES -resultBundlePath ./build.xcresult
```

Do not proceed without coverage data — guessing coverage values is not acceptable.

## Step 3: Run CRAP Analysis

For each target Swift file:
```bash
bash .claude/tools/crap-score.sh \
  --file {file} \
  --xcresult ./build.xcresult
```

## Step 4: Report

Present the CRAP table. For every function with CRAP > 30:
- State the function name, CC, coverage, and CRAP score
- Provide a specific DECRAP recommendation (reduce CC or add targeted tests)
