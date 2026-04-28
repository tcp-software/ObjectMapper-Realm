---
name: review
description: Run AI code review against repo rules and architecture patterns
argument-hint: "Optional: PR URL or branch name (defaults to current branch)"
agent: code-reviewer
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# AI Code Review

You are performing a code review on the current changes.

## Step 1: Determine Scope

If $ARGUMENTS contains a PR URL, fetch the PR diff:

```bash
gh pr diff {PR-NUMBER}
```

If $ARGUMENTS contains JIRA task, find PRs linked to that task and fetch their diffs. If there are multiple, review them all.

Otherwise, review the current branch against main:

```bash
git diff main...HEAD
```

Also get the list of changed files:

```bash
git diff main...HEAD --name-only
```

## Step 2: Load Rules

Read `.harness/rules/index.md` to determine which rule files to load.

Always load:
- `.harness/rules/general.md`
- `.harness/rules/security.md`
- `.harness/rules/pr-review.md`

Conditionally load based on which files changed:
- Test files changed → load `.harness/rules/testing.md`

Also load `.harness/ARCHITECTURE.md` to check pattern compliance.

## Step 3: Review Each File

For every changed file, check against the loaded rules. Categorize each finding:

**BLOCK** — must fix before merge. Use for:
- Security violations (from security.md)
- Secrets or credentials in code
- Disabled tests or skipped linting
- Breaking changes without documentation
- Violations of "must pass" items in pr-review.md

**FLAG** — human reviewer should evaluate. Use for:
- New dependencies added without justification
- Changes to shared utilities (downstream impact)
- Complex logic without test coverage
- Performance concerns (N+1 queries, unbounded loops, missing pagination)
- Error handling gaps

**NOTE** — suggestion, non-blocking. Use for:
- Style improvements within conventions
- Minor refactoring opportunities
- Documentation suggestions

## Step 4: Check Pattern Compliance

Using `.harness/ARCHITECTURE.md`:
- Does new code follow the established patterns?
- Are architectural boundaries respected?
- Do dependencies flow in the correct direction?
- Are new modules placed in the right location?

## Step 5: Generate Review

Format the review output:

```
## AI Code Review — [JIRA-ID from branch name]

### BLOCK (must fix before merge)
- **[file:line]** Description of the violation. Rule: [which rule file and section]

### FLAG (human reviewer should evaluate)
- **[file:line]** Description of concern.

### NOTE (suggestion, non-blocking)
- **[file:line]** Suggestion for improvement.

### Summary
- Files reviewed: {count}
- Rules checked: {list loaded rule files}
- Verdict: PASS | NEEDS ATTENTION | BLOCKED

### PASS: No BLOCK findings. FLAGs and NOTEs are informational.
### NEEDS ATTENTION: No BLOCKs but significant FLAGs that a human should review.
### BLOCKED: One or more BLOCK findings that must be resolved before merge.
```

## Rules for Reviewing

- Be specific: cite the file, line, and the exact rule being violated.
- Don't bikeshed: if it follows conventions, don't suggest alternatives.
- Stay in scope: only comment on the changes in this PR, not pre-existing code.
- Don't repeat: if the same pattern violation appears in multiple places, note it once and say "also applies to [files]."
- Be actionable: every BLOCK and FLAG should clearly state what needs to change.
