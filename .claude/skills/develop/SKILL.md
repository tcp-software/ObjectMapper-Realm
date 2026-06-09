---
name: develop
description: Implement a specific phase or sub-phase from an approved complex task plan using TDD
argument-hint: "JIRA-ID phase-id (e.g., JIRA-123 1a or JIRA-123 2)"
allowed-tools:
  - Agent
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Phase Development

Implement a specific phase or sub-phase from an approved plan using Test-Driven Development.

## Step 1: Parse Arguments

From $ARGUMENTS, extract:
- **JIRA-ID** (e.g., `JIRA-123`)
- **Phase identifier** (e.g., `1a`, `1b`, `2`)

If either is missing: stop — "Usage: /develop JIRA-ID phase-id (e.g., /develop JIRA-123 1a)"

## Step 2: Load Plan and Progress

Read `.harness/plans/{JIRA-ID}.md`.
If not found: stop — "No approved plan found. Run `/plan-complex-task` first."

Read `.harness/plans/{JIRA-ID}.progress.md`.
If not found: stop — "No progress file found. The plan may have been created before progress tracking was introduced. Run `/plan-complex-task` to regenerate."

Check the progress file for the specified phase/sub-phase:
- If status is `DONE`: warn — "Sub-phase {id} is already completed (commit: {hash}). Skip or re-implement?"
- If status is `IN PROGRESS`: note — "Resuming sub-phase {id}."
- If status is `PENDING`: proceed normally.

Locate the specified phase/sub-phase section in the plan. Extract:
- Files to change
- G/W/T scenarios covered by this phase
- Commit message

## Step 3: Worktree Check

By default, work in the existing base worktree (`feature/{jira-id}`).

If a conflict is detected during work (another agent has modified the same file — detectable via `git status` showing unexpected modifications):
- Create a dedicated sub-worktree:
  ```bash
  git worktree add ../{project-name}-phase-{N}-subphase-{X} -b feature/{jira-id}-phase-{N}-subphase-{X}
  ```
- Continue all work in the sub-worktree
- After completion: merge back to base, resolve conflicts, remove worktree and branch

## Step 4: TDD Cycle

All agents write full output to temp files and return only structured summaries.
Agents read previous phase output from disk — the orchestrator does NOT pass data inline between agents.

For each logical unit of work within the phase:

### a. RED — Write Failing Tests

**Invoke the `unit-tester` agent** with this prompt:

> "Write failing tests for these G/W/T scenarios: {scenarios from plan for this phase}.
> Read test conventions from `.harness/rules/testing.md`.
> Write full output (test files created, compilation result, test run result, scenario coverage)
> to `/tmp/{JIRA-ID}-phase{N}-red.md`.
> Return only: files created count, compile status, failing test count."

**Decision logic:**
- Compile NO → STOP. Read `/tmp/{JIRA-ID}-phase{N}-red.md` for error details.
- 0 failing tests → STOP. Tests should fail against unimplemented code.
- Compile YES + tests failing → proceed to GREEN.

### b. GREEN — Implement

**Invoke the `developer` agent** with this prompt:

> "Implement the minimum code to pass the failing tests for phase {N}.
> Read the approved plan phase content from `.harness/plans/{JIRA-ID}.md` (phase {N} section).
> Read failing test details from `/tmp/{JIRA-ID}-phase{N}-red.md`.
> Write verbose output to `/tmp/{JIRA-ID}-phase{N}-green.md`.
> Return only: files modified count, files created count, test pass/fail count."

**Decision logic:**
- Tests FAIL → read `/tmp/{JIRA-ID}-phase{N}-green.md` for failure details. Re-invoke developer or STOP.
- Tests PASS → proceed to REFACTOR.

### c. REFACTOR — Clean Up and Verify Quality

Sequential execution with early exit:

1. **SwiftLint**: `swiftlint lint {changed-files}` — must be clean (zero warnings)
   - Fail? → STOP immediately.

2. **Dependency check**: **invoke `dependency-checker` agent** with this prompt:

   > "Check architecture dependencies for these files: {changed-files list}.
   > Read `.harness/ARCHITECTURE.md` for layer boundaries.
   > Write full report to `/tmp/{JIRA-ID}-phase{N}-depcheck.md`.
   > Return only: PASS, BLOCK, or WARNING with counts."

   **Decision logic:**
   - PASS or WARNING → proceed to CRAP check.
   - BLOCK → STOP immediately. Read `/tmp/{JIRA-ID}-phase{N}-depcheck.md` for violation details.

3. **CRAP check**: **invoke `crap-analyzer` agent** with this prompt:

   > "Analyze CRAP scores for these files: {changed-files list}.
   > Write full report to `/tmp/{JIRA-ID}-phase{N}-crap.md`.
   > Return only: PASS or DECRAP with function names and scores."

   **Decision logic:**
   - PASS → proceed to commit.
   - DECRAP → read `/tmp/{JIRA-ID}-phase{N}-crap.md` for DECRAP strategies.
     Invoke `refactorer` agent: "Read CRAP analysis from `/tmp/{JIRA-ID}-phase{N}-crap.md`.
     DECRAP the flagged functions." Re-run CRAP check after refactoring.

## Step 5: Commit

```bash
git add {changed-files}
git commit -m "{commit-message-from-plan}"
```

Use the exact commit message defined in the plan for this phase/sub-phase.

## Step 5b: Update Progress

After a successful commit, update `.harness/plans/{JIRA-ID}.progress.md`:

1. Find the sub-phase section (e.g., `### Sub-phase 1a:`)
2. Change status from `PENDING` or `IN PROGRESS` to `DONE`
3. Add commit hash: `git rev-parse --short HEAD`
4. Add commit message
5. List files modified in this sub-phase
6. Update `**Last updated:**` to current date
7. Remove this sub-phase from the `## Remaining work` section

## Step 6: Sub-worktree Cleanup (only if created)

```bash
git checkout feature/{jira-id}
git merge feature/{jira-id}-phase-{N}-subphase-{X}
# resolve any conflicts
git worktree remove ../{project-name}-phase-{N}-subphase-{X}
git branch -d feature/{jira-id}-phase-{N}-subphase-{X}
```

## Step 7: Phase Checkpoint (full phases only)

When completing a **full phase** (i.e., all sub-phases of phase N are done):

1. Run the full test suite (command from `.harness/WORKFLOWS.md`)
2. `xcodebuild build -scheme {scheme}` — must compile
3. `swiftlint lint` — must be clean
4. **Mutation test** (batch mode via temp files):

   Collect changed files and run mutation-test.sh for each, writing raw output to a temp file:

   ```bash
   CHANGED_FILES=$(git diff HEAD~{n} --name-only -- '*.swift')
   echo "" > /tmp/{JIRA-ID}-phase{N}-mutations-raw.md
   for file in $CHANGED_FILES; do
     THRESHOLD={classify-by-filename-suffix per mutation-tester agent}
     echo "=== $(basename $file) ===" >> /tmp/{JIRA-ID}-phase{N}-mutations-raw.md
     bash .claude/tools/mutation-test.sh \
       --file "$file" --scheme {scheme} --threshold "$THRESHOLD" \
       --git-diff main --quiet 2>&1 >> /tmp/{JIRA-ID}-phase{N}-mutations-raw.md
   done
   ```

   **Invoke the `mutation-tester` agent** with this prompt:

   > "Analyze mutation test results for phase {N}.
   > Read raw outputs from `/tmp/{JIRA-ID}-phase{N}-mutations-raw.md`.
   > Write full analysis to `/tmp/{JIRA-ID}-phase{N}-mutations.md`.
   > Return only: PASS or FAIL with file names and scores."

   **Decision logic:**
   - PASS → proceed to update checkpoint.
   - FAIL → read `/tmp/{JIRA-ID}-phase{N}-mutations.md` for G/W/T scenarios.
     Invoke `unit-tester` agent: "Read mutation analysis from `/tmp/{JIRA-ID}-phase{N}-mutations.md`.
     Add tests to kill surviving mutations. Write output to `/tmp/{JIRA-ID}-phase{N}-red-mutations.md`."
     Re-run mutation test for failing files. Do NOT proceed until all files meet their threshold.

If any check fails: stop and report — do NOT proceed to the next phase.

#### Update Checkpoint in Progress

After all checkpoint checks pass, update `.harness/plans/{JIRA-ID}.progress.md`:

1. Find the checkpoint section (e.g., `### Phase 1 Checkpoint`)
2. Change status from `PENDING` to `DONE`
3. Update `**Last updated:**` to current date
4. Remove this checkpoint from the `## Remaining work` section

If all phases and checkpoints are `DONE`, set `**Current status:** Complete` and suggest:
"All phases complete. Run `/review` to check changes, then `/pr` to create the pull request."

Read `.claude/templates/phase-verification-summary.md` and populate the **DEVELOP variant**
with actual values for this phase.
