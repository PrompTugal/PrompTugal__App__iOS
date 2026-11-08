// swift-tools-version: 6.0
// PTCore: part of the three-apps split. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTCore",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTCore", targets: ["PTCore"]),
    ],
    targets: [
        .target(name: "PTCore"),
        .testTarget(
            name: "PTCoreTests",
            dependencies: ["PTCore"],
            path: "Tests/PTCoreTests"
        ),
    ],
    // Like every other package and the apps (SWIFT_VERSION 5.0); the moved secret store and dictation code
    // were written and tested in that mode.
    swiftLanguageModes: [.v5]
)
