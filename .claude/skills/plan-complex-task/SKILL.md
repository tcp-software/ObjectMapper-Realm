---
name: plan-complex-task
description: Generate a multi-phase implementation plan with G/W/T specification designed for parallel development by multiple agents
argument-hint: "Optional: JIRA-ID (defaults to current branch ticket)"
allowed-tools:
  - Agent
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Complex Task Planning

Generate a phased implementation plan with G/W/T specification, designed for parallel development.

## Step 1: Determine Context

```bash
git branch --show-current
```

Extract the Jira ID from the branch name. If $ARGUMENTS contains a Jira ID, use that instead.
If no Jira ID can be determined, ask the developer.

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

## Step 4: Generate Phased Plan

Check the current git state:

```bash
git diff main --stat
```

**Invoke the `complex-task-planner` agent** with:
- Jira ticket at `/tmp/{JIRA-ID}-jira.md`
- Task brief at `/tmp/{JIRA-ID}-brief.md`
- The git diff output (fresh plan vs. plan revision context)

The agent generates the G/W/T specification, decomposes work into parallelizable
phases/sub-phases, presents the plan for developer approval, and saves it to
`.harness/plans/{JIRA-ID}.md` on approval.

Confirm: "Plan saved. Run `/develop {JIRA-ID} 1a` for each sub-phase to implement in parallel."
