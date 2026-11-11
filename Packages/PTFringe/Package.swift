// swift-tools-version: 6.0
// PTFringe: the Lisbon Fringe app's event models and store. Reads lisbontechfringe.com and the storm site only,
// with a bundled seed for first launch and offline. Depends on PTCore only. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTFringe",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTFringe", targets: ["PTFringe"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
    ],
    targets: [
        .target(
            name: "PTFringe",
            dependencies: [.product(name: "PTCore", package: "PTCore")],
            resources: [.copy("Resources/seed-events.json")]
        ),
        .testTarget(
            name: "PTFringeTests",
            dependencies: ["PTFringe"],
            path: "Tests/PTFringeTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
