# Rules Index

<!--
  PURPOSE: Manifest of all rule files. AI reads THIS FIRST and only loads
  the files relevant to the current task. This saves token usage.

  LOADING STRATEGY:
  - "always" = loaded on every AI invocation (keep these small)
  - "conditional" = loaded only when the task matches the scope

  BUDGET: Each rule file should be under 500 words.
-->

| File | Scope | Load | Description |
|------|-------|------|-------------|
| general.md | All code | always | Naming, error handling, logging, code style |
| security.md | All code | always | Auth patterns, input validation, secrets handling |
| testing.md | Test files | conditional | Test structure, naming, mocking policy, coverage |
| pr-review.md | Code review phase | conditional | Review checklist, things to flag, approval criteria |
| pr-instructions/* | Code review (sub-rules) | conditional | Detailed review guidelines per category — loaded by pr-review.md |

<!--
  ADD MORE RULE FILES AS NEEDED. Keep the index updated.
  Rule files that don't appear here won't be discovered by AI tools.
-->
