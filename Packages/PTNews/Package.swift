// swift-tools-version: 6.0
// PTNews: part of the three-apps split. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTNews",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTNews", targets: ["PTNews"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../PTWeb"),
    ],
    targets: [
        .target(
            name: "PTNews",
            dependencies: [.product(name: "PTCore", package: "PTCore"), .product(name: "PTWeb", package: "PTWeb")]
        ),
        .testTarget(
            name: "PTNewsTests",
            dependencies: ["PTNews"],
            path: "Tests/PTNewsTests"
        ),
    ]
)
