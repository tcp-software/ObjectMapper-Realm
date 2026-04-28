---
applyTo: "**/*.swift"
---

# iOS Architecture Review Rules

## ARCH-01 ViewController must remain UI-only
ViewController should only handle UI rendering and user interaction.
Flag business logic, direct persistence, direct networking, or non-trivial data transformation in ViewController.

## ARCH-02 VIP flow must not be bypassed
Expected flow is:
ViewController → Interactor → Presenter → ViewController

Flag:
- direct Response → ViewController flow
- skipped Request / Response / ViewModel steps
- direct presenter/view/controller shortcuts that bypass the cycle

## ARCH-03 Coordinator owns navigation
Routing, scene assembly, and navigation belong to Coordinator.
Flag navigation performed directly in ViewController unless explicitly justified by project conventions.

## ARCH-04 Presenter transforms Response into ViewModel only
Presenter should transform Response into ViewModel and avoid view code, navigation, or business logic.

## ARCH-05 Interactor owns business logic orchestration
Interactor should coordinate workers, async flows, and business decisions.
Flag formatting logic or UI display logic inside Interactor.

## ARCH-06 Formatter handles larger formatting responsibilities
When display formatting grows, it should move from Presenter into Formatter.
Flag massive Presenter logic that is mostly formatting and display shaping.

## ARCH-07 Wrappers shield scene logic from DTOs
DTO or backend transport objects should not leak directly into scene logic where wrappers or wrapper factories are expected.

## ARCH-08 Dependencies should be protocol-based and injected
Prefer initializer injection and protocol abstractions for workers, formatters, routers/coordinators, and collaborators.
Flag hidden dependencies, lazy-created collaborators, and tight coupling.

## ARCH-09 Components should stay focused and small
Flag massive ViewControllers, Interactors, or Presenters, duplicated responsibilities, and cross-layer leakage.
