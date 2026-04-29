## Plan for HUMMOB-10358: [iOS Station] Update Realm library

### Understanding

The library currently pins `RealmSwift` to `10.49.3` via SPM `.exact()`. Realm-core's
`s2geometry` dependency in older versions specializes `std::is_pod`, which Xcode 26.4's
toolchain rejects (`-Winvalid-specialization`), breaking downstream builds. The fix is
to bump `RealmSwift` to `20.0.4` (confirmed) — newer Realm uses `std::is_trivial` and
compiles cleanly under Xcode 26.4. Because `ObjectMapper+Realm` is a transitive
dependency for the Station app, every consumer is blocked until this library ships a
compatible release.

The team has also moved entirely to SPM, so the residual CocoaPods artifacts (`Podfile`,
`Podfile.lock`, `ObjectMapper+Realm.podspec`, the CocoaPods-generated
`ObjectMapper+Realm.xcworkspace`) and the stale CircleCI config (`circle.yml`,
Xcode 8.2 / iPhone 6 era) are dead weight and should be removed in a separate phase.

**Acceptance criteria (from ticket):**
1. `RealmSwift` upgraded to `20.0.4`.
2. `ObjectMapper+Realm` library compiles and exposes a source-compatible
   `ListTransform<T: RealmSwift.Object & BaseMappable>`.
3. `swift build` succeeds in both Debug and Release under Xcode 26.4.
4. `swift test` passes — all `ListTransformTests` green.
5. No regressions in Realm operations exercised by the test suite (mapping `List<T>`
   from JSON, round-tripping objects).
6. CocoaPods and stale CI artifacts removed; SPM is the single source of truth.

### G/W/T Specification

```
Feature: Realm 20.0.4 compatibility for ObjectMapper+Realm

  Scenario: Library resolves the new Realm version via SPM
    Given Package.swift declares RealmSwift dependency at "20.0.4"
      And the dependency uses .upToNextMajor(from: "20.0.4")
    When `swift package resolve` runs against a clean build directory
    Then Package.resolved records realm-swift at 20.0.4 (or the latest 20.x)
      And no resolution errors are emitted

  Scenario: Library compiles against Realm 20.0.4
    Given Package.swift pins RealmSwift to 20.0.4
      And swift-tools-version satisfies the new Realm requirements
    When `swift build -c debug` runs
    Then the build succeeds with zero errors
      And no `is_pod` diagnostics are emitted

  Scenario: Library compiles in Release configuration under Xcode 26.4
    Given Package.swift pins RealmSwift to 20.0.4
    When `swift build -c release` runs under Xcode 26.4
    Then the build succeeds with zero errors

  Scenario: ListTransform preserves source-compatible API
    Given a public type `ListTransform<T: RealmSwift.Object & BaseMappable>`
    When the library is built against Realm 20.0.4
    Then the generic constraint and `transformFromJSON` / `transformToJSON`
         signatures remain unchanged for downstream consumers

  Scenario: Existing test suite passes against Realm 20.0.4
    Given ObjectMapper+RealmTests target compiles against the new Realm
    When `swift test` runs
    Then all ListTransformTests pass
      And test coverage remains at or above the prior baseline

  Scenario: CocoaPods artifacts are no longer present in the repo
    Given the team has migrated to SPM as the single distribution channel
    When the working tree is inspected after Phase 6
    Then Podfile, Podfile.lock, and ObjectMapper+Realm.podspec do not exist
      And the CocoaPods-generated ObjectMapper+Realm.xcworkspace does not exist
      And circle.yml does not exist

  Scenario: Repository remains buildable after CocoaPods removal
    Given Phase 6 has removed all CocoaPods and legacy CI artifacts
    When `swift build` and `swift test` run
    Then both succeed with zero errors
```

---

### Phase 1: Pre-flight verification and baseline capture
**Goal:** Confirm the target Realm tag exists, capture the current build/test baseline,
and identify any `swift-tools-version` bump required by Realm 20.x. Produces no commits
on its own — output is a short verification note used by Phases 2–5.
**Checkpoint:** `swift build` and `swift test` succeed against the current `10.49.3`
pin, baseline captured. No commit (verification phase only).

#### Sub-phase 1a — Confirm Realm 20.0.4 tag and tools-version requirement [INDEPENDENT: yes]
**Files:** none (read-only investigation)
**Tasks:**
- Verify the `v20.0.4` tag exists on `github.com/realm/realm-swift`.
- Inspect that tag's `Package.swift` to record the required `swift-tools-version`
  (this drives Sub-phase 2a).
- Note any platform deployment-target floors raised by Realm 20.x (iOS / tvOS / macOS).
**G/W/T covered:** "Library resolves the new Realm version via SPM" (precondition).

#### Sub-phase 1b — Capture current baseline [INDEPENDENT: yes]
**Files:** none (read-only)
**Tasks:**
- Run `swift build -c debug`, `swift build -c release`, and `swift test` against the
  existing `10.49.3` pin. Record pass/fail, warnings, and coverage figures.
- Confirm `git status` is clean.
**G/W/T covered:** baseline for "Existing test suite passes against Realm 20.0.4".

---

### Phase 2: Bump SPM manifest to Realm 20.0.4
**Goal:** Update `Package.swift` so `swift package resolve` pulls Realm 20.0.4 and the
package compiles with the new tools-version. This phase ends with a green `swift build`
and `swift test`.
**Checkpoint:** `swift build -c debug`, `swift build -c release`, and `swift test`
all pass; `Package.resolved` regenerated and committed.
**Commit:** `feat(HUMMOB-10358): phase-2 bump RealmSwift to 20.0.4 via SPM`

#### Sub-phase 2a — Update Package.swift manifest [INDEPENDENT: yes]
**Files:** `Package.swift`
**Tasks:**
- Bump `swift-tools-version` to whatever Realm 20.0.4 mandates (recorded in 1a).
- Change `realmVersionStr` from `"10.49.3"` to `"20.0.4"`.
- Switch the dependency declaration from `.exact(Version(realmVersionStr)!)` to
  `.upToNextMajor(from: "20.0.4")` — standard convention for library packages so
  consumer projects can resolve a single Realm version across the dep graph.
- If Realm 20.x raises platform floors, update the `platforms:` array accordingly
  (e.g. `.iOS(.v8)` -> the new minimum). Confirm with developer if a major bump is
  required, since this affects downstream apps.
**G/W/T covered:** "Library resolves the new Realm version via SPM",
"Library compiles against Realm 20.0.4".

#### Sub-phase 2b — Regenerate Package.resolved [INDEPENDENT: no, depends-on: 2a]
**Files:** `Package.resolved`
**Tasks:**
- Run `swift package resolve` to regenerate the lockfile.
- Verify the resolved entry for `realm-swift` is `20.0.4` (or the highest 20.x
  satisfying the range) and ObjectMapper is unchanged.
- Stage the regenerated `Package.resolved` for the Phase 2 commit.
**G/W/T covered:** "Library resolves the new Realm version via SPM".

---

### Phase 3: Source compatibility shims for `ObjectMapper+Realm`
**Goal:** Adjust library source if Realm 20.x changes any API surface used by
`ListTransform.swift`. If the library compiles unchanged, this phase is a no-op and is
skipped (with a note in the progress file). The CocoaPods-related sub-phase from the
earlier draft has been removed — those files are deleted in Phase 6, not updated here.
**Checkpoint:** `swift build -c debug` succeeds; `ListTransform`'s public signature
unchanged from the user's perspective.
**Commit:** `feat(HUMMOB-10358): phase-3 align ListTransform with Realm 20.0.4 API`
(skip if no source changes were required)

#### Sub-phase 3a — Adjust ListTransform.swift if Realm API shifted [INDEPENDENT: yes]
**Files:** `ObjectMapper+Realm/ListTransform.swift`
**Tasks:**
- Build against the new pin and address any compiler diagnostics.
- Preserve the public generic constraint
  `ListTransform<T: RealmSwift.Object & BaseMappable>` exactly.
- Internal helpers may change; the public surface must not.
- If the build is clean with zero changes, mark this sub-phase as N/A in the progress
  file and move on.
**G/W/T covered:** "ListTransform preserves source-compatible API",
"Library compiles against Realm 20.0.4".

---

### Phase 4: Test target compatibility
**Goal:** Ensure `ObjectMapper+RealmTests` compiles and all tests pass against Realm
20.0.4. Test framework remains XCTest — Swift Testing migration is explicitly out of
scope for this ticket.
**Checkpoint:** `swift test` is green; coverage at or above the Phase 1b baseline.
**Commit:** `feat(HUMMOB-10358): phase-4 update tests for Realm 20.0.4`
(skip if no test source changes were required)

#### Sub-phase 4a — Update User.swift fixture if Realm.Object API shifted [INDEPENDENT: yes]
**Files:** `ObjectMapper+RealmTests/User.swift`
**Tasks:**
- Address any compiler issues caused by Realm 20.x changes to `Object`'s init or
  property-declaration conventions (e.g. `@objc dynamic var` vs. `@Persisted`).
- Keep the schema semantically identical so existing tests remain meaningful.
**G/W/T covered:** "Existing test suite passes against Realm 20.0.4".

#### Sub-phase 4b — Adjust ListTransformTests.swift if assertions break [INDEPENDENT: no, depends-on: 4a]
**Files:** `ObjectMapper+RealmTests/ListTransformTests.swift`
**Tasks:**
- Re-run `swift test` and update assertions only if Realm's behavior changed
  semantically (it should not — `List<T>` mapping is API-stable).
- Do not introduce new test cases here; new coverage is out of scope for this ticket.
**G/W/T covered:** "Existing test suite passes against Realm 20.0.4".

---

### Phase 5: End-to-end Xcode 26.4 verification
**Goal:** Confirm Debug and Release both build cleanly under Xcode 26.4 (the primary
acceptance gate from the ticket). No code changes — pure verification phase.
**Checkpoint:** Debug + Release builds green under Xcode 26.4, full test suite green,
no `is_pod` diagnostics anywhere in the build log.
**Commit:** none (verification only); record results in the progress file.

#### Sub-phase 5a — Debug build verification [INDEPENDENT: yes]
**Files:** none
**Tasks:**
- `swift build -c debug` under Xcode 26.4. Capture the full log.
- Grep the log for `is_pod` and any `-Winvalid-specialization` diagnostics — must be
  zero hits.
**G/W/T covered:** "Library compiles against Realm 20.0.4".

#### Sub-phase 5b — Release build verification [INDEPENDENT: yes]
**Files:** none
**Tasks:**
- `swift build -c release` under Xcode 26.4. Capture the full log.
- Same diagnostic grep as 5a.
**G/W/T covered:** "Library compiles in Release configuration under Xcode 26.4".

#### Sub-phase 5c — Full test suite re-run [INDEPENDENT: yes]
**Files:** none
**Tasks:**
- `swift test` final pass; record pass/fail and coverage delta vs. Phase 1b baseline.
**G/W/T covered:** "Existing test suite passes against Realm 20.0.4".

---

### Phase 6: Remove CocoaPods and legacy CI artifacts
**Goal:** Strip CocoaPods and stale CI files now that the team has fully moved to SPM.
This phase runs **only after Phase 5 is green** so we never conflate "bump Realm"
with "remove CocoaPods" in a single commit. Each sub-phase here is its own commit so
a single `git revert` cleanly undoes any one removal if a downstream consumer surfaces
an unexpected dependency.
**Checkpoint:** `swift build` and `swift test` still pass after every removal; working
tree contains no Podfile, Podfile.lock, podspec, CocoaPods workspace, or `circle.yml`.
**Commit:** see per-sub-phase commits below.

#### Sub-phase 6a — Remove Podfile and Podfile.lock [INDEPENDENT: yes]
**Files:** `Podfile`, `Podfile.lock`
**Tasks:**
- Delete `Podfile` and `Podfile.lock`.
- Confirm `git status` shows only those two deletions.
- Run `swift build` and `swift test` to verify nothing implicit relied on them.
**G/W/T covered:** "CocoaPods artifacts are no longer present in the repo",
"Repository remains buildable after CocoaPods removal".
**Commit:** `chore(HUMMOB-10358): phase-6a remove Podfile and Podfile.lock`

#### Sub-phase 6b — Remove ObjectMapper+Realm.podspec [INDEPENDENT: yes]
**Files:** `ObjectMapper+Realm.podspec`
**Tasks:**
- Delete `ObjectMapper+Realm.podspec`.
- Note in the commit message that CocoaPods distribution is dropped — SPM is the
  single channel going forward.
**G/W/T covered:** "CocoaPods artifacts are no longer present in the repo".
**Commit:** `chore(HUMMOB-10358): phase-6b drop CocoaPods distribution (remove podspec)`

#### Sub-phase 6c — Remove CocoaPods-generated xcworkspace [INDEPENDENT: yes]
**Files:** `ObjectMapper+Realm.xcworkspace/` (entire directory)
**Tasks:**
- Confirm the workspace's `contents.xcworkspacedata` references `Pods/Pods.xcodeproj`
  (this verifies it is the CocoaPods-generated workspace, not a hand-curated one).
- Delete the directory.
- Confirm the SwiftPM-generated workspace (under `.swiftpm/`) and the `.xcodeproj`
  are still intact. Developers will use SwiftPackage / `.xcodeproj` going forward,
  per the project CLAUDE.md SPM-library guidance.
**G/W/T covered:** "CocoaPods artifacts are no longer present in the repo".
**Commit:** `chore(HUMMOB-10358): phase-6c remove CocoaPods-generated xcworkspace`

#### Sub-phase 6d — Remove stale circle.yml [INDEPENDENT: yes]
**Files:** `circle.yml`
**Tasks:**
- Delete `circle.yml` (Xcode 8.2 / iPhone 6 / 2016-era config; references `pod install`
  which no longer exists post-6a).
- Note in commit message that CI is no longer driven from this file; if the team wants
  CI for this library, a new workflow will be added in a separate ticket.
**G/W/T covered:** "CocoaPods artifacts are no longer present in the repo".
**Commit:** `chore(HUMMOB-10358): phase-6d remove stale circle.yml`

#### Sub-phase 6e — Final post-removal verification [INDEPENDENT: no, depends-on: 6a-6d]
**Files:** none
**Tasks:**
- Run `swift build -c debug`, `swift build -c release`, and `swift test` one more time.
- Confirm `git status` is clean.
- Update progress file with the final green run.
**G/W/T covered:** "Repository remains buildable after CocoaPods removal".
**Commit:** none (verification only).

---

### Risks & Open Questions

**Resolved decisions:**
- **(a) Realm version target:** `20.0.4` — confirmed.
- **(b) Test framework:** XCTest stays. Swift Testing migration is out of scope.
- **(c) `circle.yml`:** confirmed dead, removed in Sub-phase 6d.
- **(d) SPM pinning strategy:** switching from `.exact()` to
  `.upToNextMajor(from: "20.0.4")`. Standard for library packages — avoids version
  conflicts in consumer dep graphs.
- **(e) CocoaPods artifacts:** all removed in Phase 6 (Podfile, Podfile.lock,
  podspec, CocoaPods-generated xcworkspace). SPM is the single distribution channel.

**Remaining risks:**
- **R1 — Platform deployment target floor.** Realm 20.x almost certainly raises the
  iOS/tvOS/macOS minimums above the current `.iOS(.v8) / .tvOS(.v10) / .macOS(.v10_10)`.
  Sub-phase 2a will surface the required floors; if the bump is large, the developer
  should confirm before merging since downstream apps inherit it.
- **R2 — Realm `Object` property declaration style.** Realm 20.x emphasizes
  `@Persisted` over `@objc dynamic var`. The test fixture `User.swift` may need
  rewriting under Sub-phase 4a. The library itself uses generics over
  `RealmSwift.Object`, so it should be unaffected, but compile diagnostics in 3a/4a
  will confirm.
- **R3 — `swift-tools-version` bump.** If Realm 20.x requires `swift-tools-version`
  >= `5.9` or `6.0`, that's a transitive constraint on every consumer. Sub-phase 1a
  pins this number down before any commit lands.
- **R4 — Downstream library consumers (CocoaPods).** Removing the podspec is a
  breaking change for any consumer still pulling via CocoaPods. Per developer
  decision (e), the team has fully moved to SPM, but if any external/internal repo
  is still on Pods this should be flagged in the PR description so the migration is
  visible.

**Story-point sanity check:** Estimated 5–8 SP. Well under the 20-SP threshold —
no need to split the ticket.
