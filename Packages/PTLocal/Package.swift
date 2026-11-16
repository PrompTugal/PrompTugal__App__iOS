// swift-tools-version: 6.0
// PTLocal: PrompTugal.news by place (Portugal, the Algarve, its 17 towns) and the newsroom behind it, read-only.
// Depends on PTCore only. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTLocal",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTLocal", targets: ["PTLocal"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
    ],
    targets: [
        .target(
            name: "PTLocal",
            dependencies: [.product(name: "PTCore", package: "PTCore")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PTLocalTests",
            dependencies: ["PTLocal", .product(name: "PTCore", package: "PTCore")],
            path: "Tests/PTLocalTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
