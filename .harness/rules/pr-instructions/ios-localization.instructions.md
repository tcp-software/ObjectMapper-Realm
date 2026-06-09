---
applyTo:
  - "**/*.swift"
  - "**/*.strings"
  - "**/*.xcstrings"
---

# Localization Review Rules

## L10N-01 No hardcoded user-facing strings
User-visible text should use the project localization mechanism, for example localized keys.

## L10N-02 Avoid string concatenation for localized sentences
Do not assemble user-facing copy with concatenation or interpolation when word order may vary by language.

## L10N-03 Support pluralization properly
Count-based strings should use plural-aware localization patterns.

## L10N-04 Use locale-aware date, number, and currency formatting
Flag manual or locale-unsafe formatting.

## L10N-05 New user-facing text must include localization coverage
Verify added text follows project key naming and translation expectations.

## L10N-06 Localization logic should live in the correct layer
Flag display copy assembled too deep in workers/wrappers or business logic that bypasses Presenter / Formatter responsibilities.
