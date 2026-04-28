# Testing Rules

<!-- LOAD: conditional — plan and review phases | BUDGET: under 500 words -->

## TDD Workflow (Uncle Bob's Three Rules)

1. **Do not write production code except to pass a failing test.**
2. **Do not write more of a test than is sufficient to fail** (including compile failures).
3. **Do not write more production code than is sufficient to pass.**

Cycle: Red → Green → Refactor. Every production file must have a corresponding test file before the implementation is considered complete.

## Test Framework & Structure

- Use **Swift Testing** (`import Testing`) as the primary test framework.
- Tests mirror source structure: `{Module}Tests/{Scene}/{Scene}InteractorTests.swift`.
- One test struct per production class. File name matches: `{ProductionClass}Tests.swift`.
- Use `init()` for shared arrangement (create SUT + inject mocks). Structs deallocate automatically; explicit teardown is rarely needed.
- Tag tests by module for selective execution:
  ```swift
  extension Tag {
      @Tag static var auth: Self
      @Tag static var payment: Self
      @Tag static var profile: Self
  }

  @Test(.tags(.auth))
  func fetchUser_withValidID_returnsUserViewModel() { ... }
  ```
- Run module-scoped tests via Xcode Test Plans configured per tag, or filter in CLI: `xcodebuild test -only-testing:{ModuleTests}` for module-level granularity.

## Test Naming

Format: `{methodUnderTest}_{scenario}_{expectedResult}` (no `test_` prefix — Swift Testing uses `@Test`).

Examples:
- `fetchUser_withValidID_returnsUserViewModel`
- `fetchUser_withExpiredToken_propagatesAuthError`
- `presentError_withNetworkTimeout_formatsRetryMessage`

Every name must be readable as a specification sentence.

## What Must Be Tested

- **Interactor:** all business logic paths, worker delegation, error propagation through Response.
- **Presenter:** every Response-to-ViewModel transformation, formatting edge cases (nil, empty, boundary values).
- **Worker:** network/persistence logic with injected mock dependencies.
- **Coordinator:** navigation calls (verify correct method invoked on router spy).
- **Formatter:** all formatting branches, locale edge cases.
- **Coverage target:** new code must achieve 80%+ line coverage. Critical business logic: 95%+.

## Mocking Policy

- Define test doubles as nested types or dedicated files in the test target: `{Protocol}Spy`, `{Protocol}Stub`, `{Protocol}Mock`.
- **Spy** captures calls for verification (method called, arguments passed). Use for VIP boundary protocols.
- **Stub** returns canned responses. Use for workers and external services.
- All test doubles must conform to the production protocol — never subclass production types.
- Never use runtime mocking frameworks; protocol-based doubles only.

## Async Testing

- Use Swift concurrency in tests: `@Test func example() async throws`.
- For Combine publishers, use `confirmation()` or collect values with async sequence.
- Never use `sleep()` or fixed delays in tests. Use deterministic scheduling or `Clock` injection.

## Test Data

- Use factory methods: `static func make(id: String = "test-id", ...) -> Model` on test helper extensions.
- Never hardcode dates — use a fixed reference date injected via protocol.
- Keep test data minimal — only set fields relevant to the assertion.

## Quality Verification Tools

After writing tests, validate quality using `.claude/tools/`:

- **`crap-score.sh`** — calculates CRAP score per function (cyclomatic complexity × uncovered code). Threshold: 30. Functions above threshold require refactoring or additional test coverage.
- **`dep-check.sh`** — validates import boundaries between CleanSwift layers. Blocks merges on layer violations.
- **`mutation-test.sh`** — applies operator mutations and verifies tests catch them. Threshold: 60%. Survived mutations indicate missing test scenarios.
- **Code coverage** — run tests with `xcodebuild test -enableCodeCoverage YES -resultBundlePath ./build.xcresult` and verify with `xcrun xccov`.

## Testing Anti-Patterns

- Never test private methods directly; test through the public interface.
- Never assert on mock internals (call count) without also asserting the outcome.
- Never share mutable state between test methods.
- Never write tests that pass without the production code they validate (tests must fail first per TDD rule 1).
- Never ignore `@MainActor` isolation in tests — match the production actor context.
