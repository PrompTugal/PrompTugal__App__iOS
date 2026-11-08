// swift-tools-version: 6.0
// PTAsk: part of the three-apps split. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTAsk",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTAsk", targets: ["PTAsk"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../PTAgenda"),
        .package(path: "../PTNews"),
        .package(path: "../PTVaultUI"),
    ],
    targets: [
        .target(
            name: "PTAsk",
            dependencies: [.product(name: "PTCore", package: "PTCore"), .product(name: "PTAgenda", package: "PTAgenda"), .product(name: "PTNews", package: "PTNews"), .product(name: "PTVaultUI", package: "PTVaultUI")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PTAskTests",
            dependencies: ["PTAsk"],
            path: "Tests/PTAskTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
