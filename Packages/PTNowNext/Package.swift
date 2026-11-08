// swift-tools-version: 6.0
// PTNowNext: the "Now and next" snapshot the apps write and their widget and intents extensions read.
// No dependencies on purpose: an extension that links only this stays small. Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTNowNext",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTNowNext", targets: ["PTNowNext"]),
    ],
    targets: [
        .target(name: "PTNowNext"),
        .testTarget(
            name: "PTNowNextTests",
            dependencies: ["PTNowNext"],
            path: "Tests/PTNowNextTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
