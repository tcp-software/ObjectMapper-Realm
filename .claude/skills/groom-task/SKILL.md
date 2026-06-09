---
name: groom-task
description: Groom a Jira ticket — fetch details, estimate story points using DoG table, assess risk, and verify definition of groomed
argument-hint: "JIRA-ID"
allowed-tools:
  - Agent
  - Read
  - Write
  - Glob
---

# Task Grooming

Prepare a Jira ticket for the development sprint by estimating story points and verifying the Definition of Groomed.

## Step 1: Determine Ticket

From $ARGUMENTS, extract the Jira ID.

If not provided, check the current branch:
```bash
git branch --show-current
```

If no Jira ID can be determined: ask the developer.

## Step 2: Fetch Ticket

**Invoke the `jira` agent** with this prompt:

> "Fetch Jira ticket {JIRA-ID} and format the full details as markdown
> (title, description, acceptance criteria, type, priority, linked tickets, epic, sprint, latest comments).
> Write the output to `/tmp/{JIRA-ID}-jira.md`.
> Return only a single line: `Saved to /tmp/{JIRA-ID}-jira.md — <ticket title>`."

Store the one-line confirmation. Do not paste the file content into the conversation.

## Step 3: Classify Scope

**Invoke the `normalizer` agent** with this prompt:

> "Read `/tmp/{JIRA-ID}-jira.md`. Classify the ticket and produce a scoped task brief
> with complexity classification, affected modules, and relevant rules from `.harness/rules/`.
> Write the brief to `/tmp/{JIRA-ID}-brief.md`.
> Return only a single line: `Saved to /tmp/{JIRA-ID}-brief.md — <one-line scope summary>`."

Store the one-line confirmation. Do not paste the file content into the conversation.

## Step 4: Groom Ticket

**Invoke the `groomer` agent** with:
- Jira ticket at `/tmp/{JIRA-ID}-jira.md`
- Task brief at `/tmp/{JIRA-ID}-brief.md`

The agent estimates story points using the DoG table, assesses risk, and presents
the complete grooming document for developer review.

## Step 5: Update Jira (optional)

Ask the developer: "Update Jira story points to {X} SP? (yes/no)"

If yes: **invoke the `jira` agent** to set the story points field.

## Step 6: Save Document

Save the grooming document to `.harness/plans/groom-{JIRA-ID}.md`.

Confirm: "Grooming complete. Document saved to `.harness/plans/groom-{JIRA-ID}.md`."
