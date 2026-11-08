// swift-tools-version: 6.0
// PTAgenda: part of the three-apps split. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTAgenda",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTAgenda", targets: ["PTAgenda"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../PTWeb"),
    ],
    targets: [
        .target(
            name: "PTAgenda",
            dependencies: [.product(name: "PTCore", package: "PTCore"), .product(name: "PTWeb", package: "PTWeb")]
        ),
        .testTarget(
            name: "PTAgendaTests",
            dependencies: ["PTAgenda"],
            path: "Tests/PTAgendaTests"
        ),
    ]
)
