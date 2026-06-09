# Claude Code Instructions

<!--
  THIS FILE IS AUTO-LOADED by Claude Code on every invocation.
  Keep it LIGHTWEIGHT — under 200 words. Heavy context lives in .harness/
  This file costs tokens on EVERY interaction, so every word counts.
-->

## Repository

SPM/CocoaPods Swift library — bridges ObjectMapper JSON mapping with RealmSwift `List<T>` via `ListTransform<T>`.

## Quick Commands

- Build: `swift build`
- Test: `swift test`
- Lint: `swiftlint lint`

## Initial Load

Before starting any task:
1. Read `.harness/rules/index.md` and load relevant rule files for the task
2. Read `.harness/CONTEXT.md` if unfamiliar with the repo

## AI Skills

- `/start-task JIRA-ID` — intake ticket, create branch, draft plan
- `/plan-task` — generate or revise change plan
- `/plan-complex-task` — generate phased implementation plan
- `/develop` — implement using TDD cycle
- `/pr` — generate PR, assign reviewers
- `/review` — AI code review against rules

## Critical Constraints

- Never push remote changes without approval
- Commit each completed phase or sub-phase after verification, marking it with the phase/sub-phase name
- Do not leave comments in class descriptions or commit messages indicating Claude agent was the editor
- Use .xcworkspace for development, not .xcproj
- For SPM libraries, use SwiftPackage workspace for build and test
- If uncertain or below 70% confidence, always ask questions to get the most accurate answer
- Never commit or push changes to the `.claude/` folder unless running `harness-sync` or `harness-init`

## Cross-Repo Context

For service registry and domain glossary, see [ios-harnessing-hub](https://github.com/tcp-software/ios-harnessing-hub).
Load only when needed.
