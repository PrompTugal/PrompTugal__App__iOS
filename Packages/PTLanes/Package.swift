// swift-tools-version: 6.0
// PTLanes: part of the three-apps split. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTLanes",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTLanes", targets: ["PTLanes"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../PTVaultUI"),
    ],
    targets: [
        .target(
            name: "PTLanes",
            dependencies: [.product(name: "PTCore", package: "PTCore"), .product(name: "PTVaultUI", package: "PTVaultUI")]
        ),
        .testTarget(
            name: "PTLanesTests",
            dependencies: ["PTLanes"],
            path: "Tests/PTLanesTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
