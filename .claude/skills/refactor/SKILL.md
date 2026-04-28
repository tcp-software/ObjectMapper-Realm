---
name: refactor
description: Plan and execute a test-first refactoring of a module, scene, or file using CleanSwift patterns
argument-hint: "Module, scene, or file path to refactor"
allowed-tools:
  - Agent
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Refactor

Plan and execute a structured refactoring with test-first discipline and CleanSwift patterns.

## Step 1: Identify Target

From $ARGUMENTS, identify the module, scene, or file to refactor.
If no argument is provided: ask the developer what to refactor.

Read the target code to understand its current structure and behavior.

## Step 2: Write Tests for Existing Behavior (CRITICAL)

**Invoke the `unit-tester` agent** to write tests covering the current behavior of the target.

These tests must:
- Pass on the CURRENT (unrefactored) code
- Cover all public behavior and critical execution paths
- Follow conventions from `.harness/rules/testing.md`

Verify all tests pass:
```bash
xcodebuild test -scheme {scheme} -destination 'platform=iOS Simulator,name=iPhone 16'
```

If any test fails on the current code: **stop immediately.**
Tell the developer: "Existing code has failing tests. Fix the bugs first before refactoring. Use `/develop` to address them."

## Step 3: Generate Refactor Plan

**Invoke the `complex-task-planner` agent** to generate a phased refactor plan.

The plan must:
- Follow CleanSwift architecture from `.harness/` Xcode templates
- Each phase addresses one structural concern and leaves code compilable and testable
- No phase changes observable behavior — structure only
- Commit message per phase: `refactor(phase-N): {module} — {description}`

Save to `.harness/plans/refactor-{module}.md` after developer approval.

## Step 4: Developer Review

Present the complete plan. Wait for explicit approval.

Confirm: "Plan saved to `.harness/plans/refactor-{module}.md`. Starting refactor — tests run after every phase."

## Step 5: Execute Refactor

**Invoke the `refactorer` agent** with the path to the approved refactor plan
(`.harness/plans/refactor-{module}.md`).

The agent executes all phases: structural changes only, compile + test verification
after each phase, SwiftLint check, CRAP score check (via bash tool), and commit per phase.

## Step 6: Final Report

After all phases complete:
- Run full test suite
- Run xcodebuild

Read `.claude/templates/phase-verification-summary.md` and populate the **REFACTOR variant**
with actual values. Use CRAP before/after columns to show structural improvement per changed function.
