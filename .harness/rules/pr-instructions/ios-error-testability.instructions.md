---
applyTo: "**/*.swift"
---

# Error Handling and Testability Review Rules

## ERR-01 Do not swallow errors
Errors should be handled, propagated, logged safely, or surfaced appropriately.

## ERR-02 User-facing failure states should exist where needed
Flag missing user-friendly error handling for network or async failures when the UX requires it.

## ERR-03 Async operations should handle success, failure, and cleanup
All async flows should have explicit handling for result paths and cleanup paths.

## TEST-01 Code should be easy to unit test
Prefer protocol-based dependencies, initializer injection, and separable business logic.

## TEST-02 Avoid hidden dependencies
Flag singleton lookups, static collaborators, or lazy-created dependencies that make mocking difficult.

## TEST-03 Keep business logic isolated from framework-heavy code
Business logic should be isolatable from UIKit and external dependencies.
