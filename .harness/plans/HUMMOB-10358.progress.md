# HUMMOB-10358 Progress

**Current status:** Complete  
**Last updated:** 2026-04-29

## Phase 1 — Pre-flight verification and baseline capture
- [x] 1a — Confirm Realm 20.0.4 tag and tools-version requirement
  - swift-tools-version: 5.10 required
  - Platform floors: iOS 12, tvOS 12, macOS 10.13
  - No commit (verification only)
- [x] 1b — Capture current baseline (build + test + coverage)
  - Debug build: FAIL (is_pod / -Winvalid-specialization in s2geometry)
  - Release build: FAIL (same)
  - Tests: not runnable (no test target declared)
  - No commit (verification only)

## Phase 2 — Bump SPM manifest to Realm 20.0.4
- [x] 2a — Update Package.swift (.upToNextMajor, swift-tools-version, platforms)
- [x] 2b — Regenerate Package.resolved
- **Commit:** `0cc33e7` — feat(HUMMOB-10358): phase-2 bump RealmSwift to 20.0.4 via SPM
- **Files:** Package.swift, Package.resolved

## Phase 3 — Source compatibility shims for ListTransform.swift
- [x] 3a — Adjust ListTransform.swift if Realm API shifted → **N/A** — library compiled with zero changes

## Phase 4 — Test target compatibility
- [x] 4a — Update User.swift fixture for Realm 20.x
  - Added Foundation import
  - NSString → String
  - @Persisted(primaryKey:) replaces @objc dynamic + primaryKey()
  - Qualified Map as ObjectMapper.Map (avoids ambiguity with RealmSwift.Map)
- [x] 4b — Adjust ListTransformTests.swift → **N/A** — no assertion changes needed
- **Commit:** `0368581` — feat(HUMMOB-10358): phase-4 update tests for Realm 20.0.4
- **Files:** ObjectMapper+RealmTests/User.swift

### Phase 2+4 Checkpoint
- [x] swift build -c debug: PASS
- [x] swift build -c release: PASS
- [x] swift test: PASS (2/2 tests green)
- [x] Zero is_pod / -Winvalid-specialization diagnostics

## Phase 5 — End-to-end Xcode 26.4 verification
- [x] 5a — Debug build: PASS — zero is_pod hits
- [x] 5b — Release build: PASS — zero is_pod hits
- [x] 5c — Test suite: PASS — testSerializeFromJson, testSerializeFromJsonFailure both green
- No commit (verification only)

## Phase 6 — Remove CocoaPods and legacy CI artifacts
- [x] 6a — Remove Podfile and Podfile.lock
  - **Commit:** `eac68a1` — chore(HUMMOB-10358): phase-6a remove Podfile and Podfile.lock
- [x] 6b — Remove ObjectMapper+Realm.podspec
  - **Commit:** `bea2b9a` — chore(HUMMOB-10358): phase-6b drop CocoaPods distribution (remove podspec)
- [x] 6c — Remove CocoaPods-generated xcworkspace (confirmed Pods/Pods.xcodeproj reference)
  - **Commit:** `f6841ce` — chore(HUMMOB-10358): phase-6c remove CocoaPods-generated xcworkspace
- [x] 6d — Remove stale circle.yml (Xcode 8.2 / pod install era)
  - **Commit:** `b3c7900` — chore(HUMMOB-10358): phase-6d remove stale circle.yml
- [x] 6e — Final post-removal verification
  - swift build -c debug: PASS
  - swift build -c release: PASS
  - swift test: PASS
  - git status: clean

---

## Build logs

### Phase 1b baseline
- swift build -c debug: **FAIL** — s2geometry `is_pod` specialization errors (Xcode 26.4 toolchain)
- Tests: not runnable — test target missing from Package.swift

### Phase 5 final
- swift build -c debug: **PASS** — Build complete, zero warnings
- swift build -c release: **PASS** — Build complete, zero warnings
- swift test: **PASS** — 2 tests, 0 failures
- is_pod grep: **0 hits** in both debug and release logs
