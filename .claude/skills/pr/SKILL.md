---
name: pr
description: Generate a pull request — run checks, draft PR, assign reviewers, update Jira
allowed-tools:
  - Agent
  - Bash
  - Read
  - Grep
  - Glob
---

# Pull Request Generation

The developer has finished implementation and wants to create a PR.

## Step 1: Pre-flight Checks

Read `.harness/WORKFLOWS.md` (or CLAUDE.md) for the test and lint commands, then run them:

```bash
# Run tests (use the actual command from WORKFLOWS.md)
```

```bash
# Run linter (use the actual command from WORKFLOWS.md)
```

If either fails, show the errors and STOP. Do not create a PR with failing tests or lint errors. Help the developer fix the issues first.

Check for uncommitted changes:

```bash
git status
```

If there are uncommitted changes, warn the developer and ask whether to commit them first.

## Step 2: Gather PR Content

Extract the Jira ID from the branch name:

```bash
git branch --show-current
```

**Invoke the `jira` agent** to fetch the ticket: title, description, acceptance criteria.
Ask developer what is the target branch (default: develop).

Get the full changeset:

```bash
git diff main --stat
git log main..HEAD --oneline
```

Read `.harness/BRANCHING.md` for PR title format and conventions.

## Step 3: Create PR and Assign Reviewers

**Invoke the `pr-creator` agent** with:
- The Jira ticket data (title, description, acceptance criteria) from Step 2
- The changeset summary (`git diff main --stat` and `git log main..HEAD --oneline`)
- Target branch from developer input (default: develop)

The agent drafts the PR body using PULL_REQUEST_TEMPLATE.md, runs `gh pr create`,
assigns reviewers from `.harness/TEAM.md`, and presents the result (PR URL, reviewers, warnings).

## Step 4: Update Jira

**Invoke the `jira` agent** to:

- Transition the ticket to "In Review" (or equivalent status)
- Add a label "Code_Review" in field labels

If the transition fails, note it but don't block — the PR is already created.

## Step 5: Clean worktree
After PR creation, delete worktree for current feature.

```bash
git worktree remove {path-to-worktree}
```

## Step 6: Cleanup

Remove progress and temp files:

```bash
rm -f .harness/plans/{JIRA-ID}.progress.md
rm -f /tmp/{JIRA-ID}-*.md
```
