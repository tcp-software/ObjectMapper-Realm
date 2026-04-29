# HUMMOB-10358 Progress

## Phase 1 — Pre-flight verification and baseline capture
- [ ] 1a — Confirm Realm 20.0.4 tag and tools-version requirement
- [ ] 1b — Capture current baseline (build + test + coverage)

## Phase 2 — Bump SPM manifest to Realm 20.0.4
- [ ] 2a — Update Package.swift (.upToNextMajor, swift-tools-version, platforms)
- [ ] 2b — Regenerate Package.resolved

## Phase 3 — Source compatibility shims for ListTransform.swift
- [ ] 3a — Adjust ListTransform.swift if Realm API shifted (may be N/A)

## Phase 4 — Test target compatibility
- [ ] 4a — Update User.swift fixture if Realm.Object API shifted (may be N/A)
- [ ] 4b — Adjust ListTransformTests.swift if assertions break (may be N/A)

## Phase 5 — End-to-end Xcode 26.4 verification
- [ ] 5a — Debug build verification
- [ ] 5b — Release build verification
- [ ] 5c — Full test suite re-run

## Phase 6 — Remove CocoaPods and legacy CI artifacts
- [ ] 6a — Remove Podfile and Podfile.lock
- [ ] 6b — Remove ObjectMapper+Realm.podspec
- [ ] 6c — Remove CocoaPods-generated xcworkspace
- [ ] 6d — Remove stale circle.yml
- [ ] 6e — Final post-removal verification

---

## Build logs

### Phase 1b baseline
_TBD_

### Phase 5 final
_TBD_
