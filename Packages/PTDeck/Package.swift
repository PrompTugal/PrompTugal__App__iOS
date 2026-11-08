// swift-tools-version: 6.0
// PTDeck: decks and presenter mode. Depends on PTCore only. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTDeck",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTDeck", targets: ["PTDeck"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
    ],
    targets: [
        .target(
            name: "PTDeck",
            dependencies: [.product(name: "PTCore", package: "PTCore")]
        ),
        .testTarget(
            name: "PTDeckTests",
            dependencies: ["PTDeck"],
            path: "Tests/PTDeckTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
