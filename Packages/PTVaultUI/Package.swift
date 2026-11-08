// swift-tools-version: 6.0
// PTVaultUI: part of the three-apps split. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTVaultUI",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTVaultUI", targets: ["PTVaultUI"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../SGitVault"),
    ],
    targets: [
        .target(
            name: "PTVaultUI",
            dependencies: [.product(name: "PTCore", package: "PTCore"), .product(name: "SGitVault", package: "SGitVault")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PTVaultUITests",
            dependencies: ["PTVaultUI"],
            path: "Tests/PTVaultUITests"
        ),
    ]
)
