---
applyTo: "**/*.swift"
---

# Swift Quality Review Rules

## SWIFT-01 Prefer `let` over `var`
Use immutable bindings unless mutation is required.

## SWIFT-02 Use `private` by default
Restrict visibility unless a broader access level is necessary.

## SWIFT-03 Avoid force unwraps without strong justification
Flag avoidable `!` usage and unsafe optional handling that can crash.

## SWIFT-04 Prefer clear naming and early exits
Names should be descriptive. Prefer `guard` for early exits when it improves readability.

## SWIFT-05 Mark classes `final` unless inheritance is needed
Use `final` by default for clarity, safety, and potential performance benefits.

## SWIFT-06 Avoid excessive nesting and overly complex methods
Extract smaller functions when methods become hard to follow or test.

## SWIFT-07 Follow project SwiftLint conventions
Flag clear lint or style violations that affect readability and maintainability.
