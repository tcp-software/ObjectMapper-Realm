---
name: start-task
description: Start work on a Jira ticket — fetch details, move to In Progress, create branch, draft plan
argument-hint: "JIRA-ID (e.g. PROJ-1234)"
allowed-tools:
  - Agent
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Ticket Intake

You are starting work on ticket: $ARGUMENTS

## Step 1: Pre-flight

Check for a clean working state before doing anything:

```bash
git status
```

If there are uncommitted changes, warn the developer and ask whether to stash or abort.
Verify the developer is on `main` (or the repo's default branch). If not, ask if they want to switch.

## Step 2: Fetch Ticket

**Invoke the `jira` agent** with this prompt:

> "Fetch Jira ticket $ARGUMENTS and format the full details as markdown
> (title, description, acceptance criteria, type, priority, linked tickets, epic, sprint).
> Write the output to `/tmp/$ARGUMENTS-jira.md`.
> Return only a single line: `Saved to /tmp/$ARGUMENTS-jira.md — <ticket title>`."

Store the one-line confirmation. Do not paste the file content into the conversation.

If the ticket is not found, show the ID and ask the developer to verify.
If the jira agent is unavailable, stop and tell the developer to check their MCP configuration.

## Step 3: Load Repo Context

**Invoke the `normalizer` agent** with this prompt:

> "Read `/tmp/$ARGUMENTS-jira.md`. Classify the ticket and produce a scoped task brief
> with relevant `.harness/rules/` files, affected modules from ARCHITECTURE.md,
> and key constraints. Write the brief to `/tmp/$ARGUMENTS-brief.md`.
> Return only a single line: `Saved to /tmp/$ARGUMENTS-brief.md — <one-line scope summary>`."

Store the one-line confirmation. Do not paste the file content into the conversation.
Also read `.harness/CONTEXT.md` if not already covered by the scope summary.

## Step 4: Move Ticket

**Invoke the `jira` agent** to transition the ticket:

1. If the status is **"Open"**: first transition to **"To Do"**, then to **"In Progress"**.
2. If the status is **"To Do"**: transition directly to **"In Progress"**.
3. If the status is already **"In Progress"**: note it and continue.
4. If any transition fails, note the error and continue — do not block the workflow.

## Step 5: Create Branch

Read `.harness/BRANCHING.md` for this repo's branching conventions. If the file doesn't exist, use these defaults:

Map ticket type to branch prefix:
- Story → `feature/`

Create branch: `{prefix}{JIRA-ID}`

Slugified title: lowercase, hyphens, max 5 words from the ticket title.

### Create Worktree First

Create a worktree for isolated development:

**Worktree naming convention:** `{project-lowercase}-feature-{JIRA-ID}`

Example: If ticket is `HUMMOB-1234`, worktree name is `proj-feature-HUMMOB-1234`

```bash
git worktree add ../{worktree-name}
cd ../{worktree-name}
```

### Create Branch Inside Worktree

Now create the feature branch inside the worktree:

```bash
git checkout -b {branch-name}
git push -u origin {branch-name}
```

If the branch already exists on remote, ask the developer: checkout existing branch or create a new one?

The worktree is now checked out with the feature branch and ready for development. Code changes made here are isolated from the main working directory.

## Step 6: Draft Plan

Check the current git state:

```bash
git diff main --stat
```

**Invoke the `task-planner` agent** with:
- Jira ticket at `/tmp/$ARGUMENTS-jira.md`
- Task brief at `/tmp/$ARGUMENTS-brief.md`
- The git diff output (to determine fresh plan vs. plan revision)

The agent drafts the implementation plan, presents it for developer approval (Approve / Modify / Reject),
and saves it to `.harness/plans/{JIRA-ID}.md` on approval.
Do NOT begin making code changes until the plan is explicitly approved.
