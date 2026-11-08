// swift-tools-version: 6.0
// PTWeb: part of the three-apps split. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTWeb",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTWeb", targets: ["PTWeb"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
    ],
    targets: [
        .target(
            name: "PTWeb",
            dependencies: [.product(name: "PTCore", package: "PTCore")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PTWebTests",
            dependencies: ["PTWeb"],
            path: "Tests/PTWebTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
