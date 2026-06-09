---
name: plan-task
description: Generate or revise a change plan for the current ticket
argument-hint: "Optional: JIRA-ID (defaults to current branch ticket)"
allowed-tools:
  - Agent
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Plan Generation

You are generating (or revising) a plan for the current work.

## Step 1: Determine Context

Check the current branch name to extract the Jira ticket ID:

```bash
git branch --show-current
```

If $ARGUMENTS contains a Jira ID, use that instead.
If no Jira ID can be determined, ask the developer for the ticket reference.

## Step 2: Fetch Ticket

**Invoke the `jira` agent** with this prompt:

> "Fetch Jira ticket {JIRA-ID} and format the full details as markdown
> (title, description, acceptance criteria, type, priority, linked tickets, latest comments).
> Write the output to `/tmp/{JIRA-ID}-jira.md`.
> Return only a single line: `Saved to /tmp/{JIRA-ID}-jira.md — <ticket title>`."

Store the one-line confirmation. Do not paste the file content into the conversation.

## Step 3: Load Repo Context

**Invoke the `normalizer` agent** with this prompt:

> "Read `/tmp/{JIRA-ID}-jira.md`. Classify the ticket and produce a scoped task brief
> with relevant `.harness/rules/` files, affected modules from ARCHITECTURE.md,
> and key constraints. Write the brief to `/tmp/{JIRA-ID}-brief.md`.
> Return only a single line: `Saved to /tmp/{JIRA-ID}-brief.md — <one-line scope summary>`."

Store the one-line confirmation. Do not paste the file content into the conversation.

## Step 4: Check Current State

```bash
git diff main --stat
```

## Step 5: Generate Plan

**Invoke the `task-planner` agent** with:
- Jira ticket at `/tmp/{JIRA-ID}-jira.md`
- Task brief at `/tmp/{JIRA-ID}-brief.md`
- The git diff output (to determine fresh plan vs. plan revision)

The agent generates the G/W/T specification, drafts the plan in the appropriate format,
presents it for developer approval, and saves it to `.harness/plans/{JIRA-ID}.md` on approval.
