# General Rules

<!-- LOAD: always | BUDGET: keep under 500 words -->

## Naming Conventions

- **Scene files:** `{Scene}ViewController`, `{Scene}Interactor`, `{Scene}Presenter`, `{Scene}Coordinator`, `{Scene}Models`.
- **Protocols:** `{Scene}BusinessLogic`, `{Scene}PresentationLogic`, `{Scene}DisplayLogic`, `{Scene}RoutingLogic`.
- **Workers:** `{Domain}Worker` (e.g., `AuthWorker`, `PaymentWorker`). One responsibility per worker.
- **Formatters:** `{Domain}Formatter` for display-formatting extracted from Presenter.
- **Wrappers:** `{Domain}Wrapper` to shield scene logic from DTOs.
- **Extensions:** `{Type}+{Capability}.swift` (e.g., `String+Validation.swift`).
- **Constants:** group in domain-specific `enum` namespaces, never loose globals.
- **Bool names:** read as assertions — `isLoading`, `hasExpired`, `canSubmit`.

## Error Handling

- Define a domain-specific `enum` conforming to `LocalizedError` per module. Include `errorDescription` for user-facing context and a `debugDescription` for logs.
- Propagate errors through the VIP cycle: Worker throws → Interactor catches and wraps in Response → Presenter maps to user-friendly ViewModel → ViewController displays.
- Use `Result<Success, DomainError>` for worker return types; avoid raw `throws` across async boundaries.
- Map third-party errors to domain errors at the boundary (Worker or networking layer).

## Logging

- Use the project's logging wrapper (backed by `os.Logger`). Never call `os.Logger` or `print()` directly from scene code.
- Levels: `.fault` for unrecoverable state, `.error` for handled failures, `.info` for business events, `.debug` for development tracing.
- Never log PII, tokens, or full request/response bodies above `.debug` level. Use the wrapper's redaction support for sensitive values.
- Log at the boundary where the error is handled (Worker, Interactor), not at every call site.

## Code Style

- Prefer value types (`struct`, `enum`) over classes unless reference semantics or identity are required.
- Limit function bodies to ~30 lines; extract helpers or workers when exceeded.
- Use trailing closure syntax only for the final closure parameter.
- Organize file sections with `// MARK: -` in order: Properties, Init, Lifecycle, Protocol conformance, Helpers.
- Use `typealias` to clarify complex closure signatures or generic constraints.

## Comments & Documentation

- Add `///` doc comments to every public protocol method — these are the VIP contracts.
- Comment the *why* on non-obvious business rules inside Interactor logic.
- Every `// TODO:` must reference a Jira ticket ID: `// TODO: [PROJ-123] description`.
- Do not comment out code. Remove it; git preserves history.

## Anti-Patterns

- **God Interactor:** split when an Interactor exceeds ~200 lines or handles unrelated use cases.
- **ViewModel logic in ViewController:** formatting, date conversion, and string assembly belong in Presenter or Formatter.
- **Stringly-typed identifiers:** use strong types (`struct UserID`) or `enum` for identifiers, notification names, keys.
- **Nested callbacks:** refactor callback chains into `async/await` or Combine pipelines.
- **Shared mutable state:** never use global `var` or unprotected singletons for cross-scene state.
