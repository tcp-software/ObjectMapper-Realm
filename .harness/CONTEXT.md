# Repository Context

## What This Repo Does

`ObjectMapper+Realm` is a thin Swift library (SPM + CocoaPods + Carthage) that provides a single public type — `ListTransform<T>` — which bridges [ObjectMapper](https://github.com/tristanhimmelman/ObjectMapper) JSON serialization with RealmSwift's `List<T>` collection type. It allows consumers to map JSON arrays directly into managed Realm relationships by conforming their `Object` subclasses to `Mappable`. The library is distributed as an open-source pod/package; consumers are any iOS/macOS/tvOS apps that use both ObjectMapper and RealmSwift.

## Domain Concepts

- **ListTransform** — the only public type; a `TransformType` struct that converts `[Any]` JSON ↔ `List<T>` for ObjectMapper
- **onSerialize** — optional callback injected at `ListTransform` init time; called after JSON→List conversion so the consumer can persist the list in a Realm write transaction
- **TransformType** — ObjectMapper protocol; requires `transformFromJSON` and `transformToJSON`
- **BaseMappable** — ObjectMapper base protocol that `Mappable` inherits from; used as generic constraint alongside `RealmSwift.Object`
- **List\<T\>** — RealmSwift's ordered collection type for to-many relationships; created unmanaged inside `transformFromJSON`, then managed once the parent Object is added to Realm

## Service Boundaries

### In Scope
- `ListTransform<T>` implementation and its public API
- Test model (`User`) and unit tests covering JSON→List and List→JSON paths
- SPM / CocoaPods / Carthage packaging configuration

### Out of Scope
- Networking or JSON fetching
- Full Realm schema definition (consumers own their `Object` subclasses)
- App-level architecture, persistence strategy, or Realm configuration
- Any Realm sync / Atlas Device Sync functionality

## Key Decisions

- **Exact SPM version pins** — both `RealmSwift` and `ObjectMapper` are pinned exactly to avoid silent breakage when upstream releases new versions
- **`onSerialize` callback pattern** — Realm writes must happen inside a transaction owned by the caller; the library intentionally avoids owning a `Realm` instance to stay thread-safe
- **No stored Realm reference** — `ListTransform` is a value type (`struct`) with no Realm dependency at rest; this avoids threading violations

## Tech Stack

- Language: Swift 5.9
- RealmSwift: 10.49.3 (SPM exact pin) / ~10.45.0 (CocoaPods)
- ObjectMapper: 4.2.0 (SPM exact pin)
- Distribution: Swift Package Manager, CocoaPods (podspec v1.2.1), Carthage
- Platforms: iOS 8+ / tvOS 10+ / macOS 10.10+ (SPM); iOS 13+ / tvOS 13+ / macOS 11+ (podspec)

## Quick Reference

- Core implementation — `ObjectMapper+Realm/ListTransform.swift`
- SPM manifest — `Package.swift`
- CocoaPods spec — `ObjectMapper+Realm.podspec`
- Test model — `ObjectMapper+RealmTests/User.swift`
- Unit tests — `ObjectMapper+RealmTests/ListTransformTests.swift`
