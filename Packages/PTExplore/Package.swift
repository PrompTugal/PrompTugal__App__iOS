// swift-tools-version: 6.0
// PTExplore: talks, speakers, companies and places. Depends on PTCore only. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTExplore",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTExplore", targets: ["PTExplore"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
    ],
    targets: [
        .target(
            name: "PTExplore",
            dependencies: [.product(name: "PTCore", package: "PTCore")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PTExploreTests",
            dependencies: ["PTExplore"],
            path: "Tests/PTExploreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
