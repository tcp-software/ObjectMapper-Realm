# Dependencies

## Upstream (libraries we depend on)

- **RealmSwift** (repo: `realm/realm-swift`) — provides `Object` base class, `List<T>` collection type; hard dependency; pinned to `10.49.3` exact in SPM, `~> 10.45.0` in CocoaPods
- **ObjectMapper** (repo: `tristanhimmelman/ObjectMapper`) — provides `TransformType`, `Mapper<T>`, `BaseMappable`; hard dependency; pinned to `4.2.0` exact in SPM

## Downstream (consumers that depend on us)

- Any iOS/macOS/tvOS app using both ObjectMapper and RealmSwift that needs JSON array → `List<T>` mapping
- No known internal TCP Software apps currently tracked here — update when known

## Shared Libraries

None — this is a standalone open-source library with no internal shared packages.

## API Contracts

No OpenAPI/protobuf specs. The public API surface is:

```swift
// ListTransform.swift — the entire public API
public struct ListTransform<T: RealmSwift.Object & BaseMappable>: TransformType {
    public typealias Object = List<T>
    public typealias JSON = Array<Any>
    public typealias Serialize = (List<T>) -> ()

    public init(onSerialize: @escaping Serialize = { _ in })
    public func transformFromJSON(_ value: Any?) -> List<T>?
    public func transformToJSON(_ value: Object?) -> JSON?
}
```

## Breaking Change Policy

- **Semver** — patch for bug fixes, minor for new non-breaking features, major for any breaking change to `ListTransform`'s public API
- Any change to `transformFromJSON`, `transformToJSON`, or the `Serialize` typealias signature is a **breaking change** → requires major version bump and podspec version update
- Realm / ObjectMapper version bumps that drop platform support are **breaking** → major bump required
- Deprecation notice not required for open-source library, but a CHANGELOG entry is expected for every release
