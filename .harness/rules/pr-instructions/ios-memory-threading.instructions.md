---
applyTo: "**/*.swift"
---

# Memory and Threading Review Rules

## MEM-01 Avoid retain cycles in escaping closures
Use `[weak self]` where appropriate in escaping closures to avoid leaking ViewController, Coordinator, Presenter, or Interactor instances.

## MEM-02 Delegates should not be strongly retained
Delegates should usually be `weak` when class-bound.

## MEM-03 Avoid strong IBOutlet references
Flag strong IBOutlets where weak is expected.

## THR-01 UI updates must happen on the main thread
All UI mutations must run on the main thread.
Flag background-thread UI updates or missing main-thread dispatch.

## THR-02 Async flows must clean up properly
Ensure loaders, activity indicators, and transient state are cleaned up on success, failure, and completion paths.

## THR-03 Background work must stay off the main thread
Flag expensive parsing, formatting, image processing, or blocking work on the main thread.
