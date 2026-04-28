# Architecture

## Module Structure

```
ObjectMapper+Realm/          — library source target (1 file)
  ListTransform.swift        — public API: ListTransform<T> struct

ObjectMapper+RealmTests/     — test target
  User.swift                 — Realm Object + Mappable test model
  ListTransformTests.swift   — XCTest suite for JSON↔List conversion
```

## Data Flow

**Deserialization (JSON → Realm List):**
```
JSON ([Any]?)
  → ListTransform.transformFromJSON(_:)
    → Mapper<T>().mapArray(JSONObject:)   // ObjectMapper creates [T] from JSON
    → List<T>.append(objectsIn: [T])      // unmanaged List populated
    → onSerialize(list)                   // consumer writes List to Realm
  → List<T>?                             // returned to ObjectMapper mapping engine
```

**Serialization (Realm List → JSON):**
```
List<T>?
  → ListTransform.transformToJSON(_:)
    → value?.compactMap { $0.toJSON() }  // ObjectMapper serializes each Object
  → [[String: Any]]?
```

## External Integrations

- **ObjectMapper** (github.com/tristanhimmelman/ObjectMapper) — JSON mapping framework; `TransformType` protocol consumed, `Mapper<T>` and `BaseMappable` used as constraint
- **RealmSwift** (github.com/realm/realm-swift) — persistence framework; `List<T>` and `RealmSwift.Object` used as type constraint and collection

## Data Storage

This library has no direct data storage. It produces `List<T>` values that consumers persist via their own Realm write transactions through the `onSerialize` callback.

## Key Patterns

- **`TransformType` protocol** — the single extension point ObjectMapper provides for custom type mapping; all logic lives here
- **Generic struct with dual constraint** — `ListTransform<T: RealmSwift.Object & BaseMappable>` enforces that `T` is both a Realm model and an ObjectMapper-mappable type
- **Callback injection at init** — `onSerialize` is passed at construction time, keeping the transform stateless and reusable across mapping calls
- **Unmanaged List creation** — `List<T>()` is created fresh per `transformFromJSON` call; it becomes managed only when the parent Object is added to Realm by the consumer
