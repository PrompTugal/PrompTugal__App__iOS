// swift-tools-version: 6.0
// PTPlaces: PrompTugal.news by place (Portugal, the Algarve and its 17 towns), read from the website's
// by-place data, drawn as a visual magazine with maps and connections, with the agents behind each place
// (conductor-report/v1). Depends on PTCore, and PTNowNext for the "My town" widget snapshot. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTPlaces",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTPlaces", targets: ["PTPlaces"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../PTNowNext"),
    ],
    targets: [
        .target(
            name: "PTPlaces",
            dependencies: [.product(name: "PTCore", package: "PTCore"), .product(name: "PTNowNext", package: "PTNowNext")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PTPlacesTests",
            dependencies: ["PTPlaces", .product(name: "PTCore", package: "PTCore")],
            path: "Tests/PTPlacesTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
