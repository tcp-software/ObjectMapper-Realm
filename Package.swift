// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "ObjectMapper+Realm",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12),
        .macOS(.v10_13),
    ],
    products: [
        .library(
            name: "ObjectMapper+Realm",
            targets: ["ObjectMapper+Realm"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/realm/realm-swift", from: "20.0.4"),
        .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", exact: "4.2.0"),
    ],
    targets: [
        .target(
            name: "ObjectMapper+Realm",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "ObjectMapper", package: "ObjectMapper"),
            ],
            path: "ObjectMapper+Realm",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "ObjectMapper+RealmTests",
            dependencies: [
                .target(name: "ObjectMapper+Realm"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "ObjectMapper", package: "ObjectMapper"),
            ],
            path: "ObjectMapper+RealmTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
let version = Version(0, 7, 0)
