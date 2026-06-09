# PR Review Rules

<!-- LOAD: conditional — code review phase only | BUDGET: under 500 words -->

## Review Checklist

<!--
  Detailed rules live in .harness/rules/pr-instructions/ — each category links its file.
-->

### Must Pass (block merge if violated)

**Security** → [ios-security.instructions.md](pr-instructions/ios-security.instructions.md)
- SEC-01: No tokens, credentials, or PII written to logs
- SEC-02, SEC-03: No unsafe optional handling or unchecked external input that can crash
- SEC-05: No sensitive data stored in UserDefaults, plist, or hardcoded constants

**Architecture** → [ios-architecture.instructions.md](pr-instructions/ios-architecture.instructions.md)
- ARCH-01: No business logic, persistence, or networking in `ViewController`
- ARCH-02: VIP flow not bypassed (`ViewController → Interactor → Presenter → ViewController`)
- ARCH-03: All navigation in `Coordinator` — never `present`/`push` directly from `ViewController`

**Memory & Threading** → [ios-memory-threading.instructions.md](pr-instructions/ios-memory-threading.instructions.md)
- THR-01: All UI mutations on the main thread
- MEM-01: `[weak self]` used in escaping closures referencing view-layer objects
- MEM-02: Delegates declared `weak`

**Localization** → [ios-localization.instructions.md](pr-instructions/ios-localization.instructions.md)
- L10N-01: No hardcoded user-facing strings
- L10N-05: Every new user-facing string has localization coverage

### Should Review (flag for human reviewer)

**Error handling & testability** → [ios-error-testability.instructions.md](pr-instructions/ios-error-testability.instructions.md)
- ERR-01: No swallowed errors (empty `catch`, ignored `Result.failure`)
- ERR-02: User-facing failure states exist for network/async failures
- TEST-01, TEST-02: Business logic injectable and mockable — no hidden singleton/static dependencies

**Architecture depth** → [ios-architecture.instructions.md](pr-instructions/ios-architecture.instructions.md)
- ARCH-05: No formatting or display logic inside `Interactor`
- ARCH-08: Dependencies injected via protocols, not created internally
- ARCH-09: No massive VIP component — split if responsibilities diverge

**Threading cleanup** → [ios-memory-threading.instructions.md](pr-instructions/ios-memory-threading.instructions.md)
- THR-02: Loaders and transient state cleaned up on all async result paths (success, failure, cancel)
- THR-03: No expensive work (parsing, formatting, image processing) blocking the main thread

### Style & Consistency

**Swift quality** → [ios-swift-quality.instructions.md](pr-instructions/ios-swift-quality.instructions.md)
- SWIFT-01: `let` over `var` unless mutation is required
- SWIFT-02: `private` by default — broader access only when necessary
- SWIFT-03: No force unwraps without documented justification
- SWIFT-05: Classes `final` by default
- SWIFT-07: No SwiftLint violations

**Localization style** → [ios-localization.instructions.md](pr-instructions/ios-localization.instructions.md)
- L10N-02: No string concatenation for user-facing copy
- L10N-04: Locale-aware formatting for dates, numbers, and currency

## Review Output Format

Sourced from `pr-instructions/pr-instructions.md` — use exactly these prefixes:

- 🔴 **Must fix** — `[file:line]` description + why it matters + rule ID (e.g. `ARCH-02`)
- 🟡 **Should fix** — `[file:line]` description + why it matters + rule ID
- 🟢 **Nice to have** — `[file:line]` suggestion, non-blocking

Every comment must be concise, technical, and constructive. Do not suggest large rewrites unless unavoidable.

## Out of Scope

- Do not bikeshed naming if it follows project conventions
- Do not suggest refactors to code outside the PR diff
- Do not recommend new third-party libraries unless directly relevant to a flagged issue
- Do not flag style issues that SwiftLint catches automatically
