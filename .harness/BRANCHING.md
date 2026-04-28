# Branching & PR Conventions

<!--
  PURPOSE: Rules for branch creation and PR formatting.
  Used by the /start-task and /pr commands in the AI workflow.
  UPDATE: When branching strategy or PR process changes.
-->

## Branch Naming

<!--
  Override the global default here if this repo uses a different convention.
-->

Format: `{type}/{JIRA-ID}`

Types:
- `feature/` — new functionality
- `hotfix/` — production emergency fixes
- `release/` — release branches, format: `release/{version}`

Examples:
- `feature/PROJ-1234`
- `hotfix/PROJ-5678`
- `release/2.3`

## Commit Messages

<!-- Commit message format. Keep it simple. -->

Format: `{type}(scope): description [JIRA-ID]`

Example: `feat(payments): add retry logic with exponential backoff [PROJ-1234]`

## Pull Request Template

- Use PR template from the .github folder named PULL_REQUEST_TEMPLATE.md

### Title

Format: `[JIRA-ID] Short description`

### Description Must Include

- Link to Jira ticket
- Summary of changes (what and why)
- Testing done
- Breaking changes (if any)
- Deployment notes (if any)

## Merge Strategy

<!-- squash / merge commit / rebase — and any rules about when to use which -->

## Reviewer Assignment

<!--
  How reviewers are assigned. CODEOWNERS? Manual? Round-robin?
  Minimum approvals required.
-->
