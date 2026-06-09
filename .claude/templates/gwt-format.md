# G/W/T Specification Format

Canonical Gherkin format used by all planning agents and skills.

```gherkin
Feature: [Feature Name]

  Scenario: [Happy path description]
    Given [system state / precondition]
    When [user action or triggering event]
    Then [expected observable outcome]

  Scenario: [Failure / edge case description]
    Given [precondition]
    When [invalid input or edge condition]
    Then [expected error behavior or fallback]
```

## Rules

- One `Feature` block per ticket
- Minimum one `Scenario` per acceptance criterion
- Each scenario must include: at least one happy path, one failure path, one boundary condition
- Use concrete, observable language — not "it works" but "the user sees X items"
