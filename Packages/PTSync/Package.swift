// swift-tools-version: 6.0
// PTSync: manifest delta sync, a content store with atomic generations, and an offline outbox. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTSync",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTSync", targets: ["PTSync"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
    ],
    targets: [
        .target(
            name: "PTSync",
            dependencies: [.product(name: "PTCore", package: "PTCore")]
        ),
        .testTarget(
            name: "PTSyncTests",
            dependencies: ["PTSync"],
            path: "Tests/PTSyncTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
