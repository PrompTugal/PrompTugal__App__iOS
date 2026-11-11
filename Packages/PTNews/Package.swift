// swift-tools-version: 6.0
// PTNews: part of the three-apps split. Apple SDK only. SGitVault plays the interview videos from their public vault.
import PackageDescription

let package = Package(
    name: "PTNews",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTNews", targets: ["PTNews"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../PTWeb"),
        .package(path: "../SGitVault"),
    ],
    targets: [
        .target(
            name: "PTNews",
            dependencies: [.product(name: "PTCore", package: "PTCore"), .product(name: "PTWeb", package: "PTWeb"),
                           .product(name: "SGitVault", package: "SGitVault")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PTNewsTests",
            dependencies: ["PTNews"],
            path: "Tests/PTNewsTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
