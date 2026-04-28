# Phase Verification Summary — Template

Populate every section with actual values. Use `N/A` with a reason if data is unavailable.

## Status icons
- ✅ passed / clean / within threshold
- ⚠️ warning — does not block, but human should review
- ❌ failed / blocked — must be resolved before proceeding

---

## DEVELOP variant
*Use this after completing a full phase in `/develop`.*

```markdown
## Phase {N} — Verification Summary

### Build
| Status | Target |
|--------|--------|
| ✅ PASS / ❌ FAIL | {scheme name or package path} |

### Tests
| Passed | Failed | Skipped | Duration |
|--------|--------|---------|----------|
| {n}    | {n}    | {n}     | {t}s     |

> If any test failed: list each failing test name and the assertion message.

### Code Coverage
| File | Coverage |
|------|----------|
| {FileName.swift} | {n}% |
| **Total** | **{n}%** |

> N/A — coverage not configured in `.harness/WORKFLOWS.md`

### SwiftLint
| Status | Warnings |
|--------|----------|
| ✅ clean / ⚠️ dirty | {n} |

> If warnings > 0: list each (file:line — rule name).

### Dependency Layers
| Status | Violations |
|--------|------------|
| ✅ clean / ❌ blocked | {n} |

> If violations > 0: list each (file:line — import — layer boundary broken).

### CRAP Scores
| Function | CC | Coverage | CRAP | Status |
|----------|----|----------|------|--------|
| {ClassName.functionName} | {n} | {n}% | {n} | ✅ ≤30 / ⚠️ >30 |

> Only functions changed in this phase. If all ≤ 30: "All functions within threshold."

### Mutation Testing
| File | Mutations | Killed | Survived | Score | Threshold | Status |
|------|-----------|--------|----------|-------|-----------|--------|
| {FileName.swift} | {n} | {n} | {n} | {n}% | {n}% | ✅ PASS / ❌ FAIL |

> If survived > 0: list each (line — op → newop — type) with the G/W/T scenario needed to kill it.

### Changed Files
| File | Tests Added |
|------|-------------|
| `{path/FileName.swift}` | {n} |

### Commit
| Hash | Message |
|------|---------|
| `{short-hash}` | {commit message} |
```

---

## REFACTOR variant
*Use this after completing a full phase in `/refactor`.*

Same as DEVELOP variant, except the **CRAP Scores** section uses before/after columns:

```markdown
### CRAP Scores
| Function | CC before | CC after | CRAP before | CRAP after | Delta |
|----------|-----------|----------|-------------|------------|-------|
| {ClassName.functionName} | {n} | {n} | {n} | {n} | ↓{n} / ↑{n} / — |
```

> Delta direction: ↓ improved, ↑ regressed (requires DECRAP before proceeding), — unchanged.

All other sections (Build, Tests, Coverage, SwiftLint, Dep layers, Mutation, Changed Files, Commit)
are identical to the DEVELOP variant.
