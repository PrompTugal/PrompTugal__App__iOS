// swift-tools-version: 6.0
// PTTalk: owner-only talk from the news app. Send to the conductor (text and a screenshot or photo), contribute a
// photo, video or recorded interview as a draft for a town, and talk to a town's agent, all sealed to append lanes
// (PTLanes' sgit hybrid envelope). Apple Intelligence answers from the town's published data meanwhile.
// Ported in part from VoiceDebrief (github.com/VoiceDebrief/VoiceDebrief__App__iOS, Apache 2.0): see NOTICE.md.
// Apple SDK only.
import PackageDescription

let package = Package(
    name: "PTTalk",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PTTalk", targets: ["PTTalk"]),
    ],
    dependencies: [
        .package(path: "../PTCore"),
        .package(path: "../PTLanes"),
        .package(path: "../PTLocal"),
    ],
    targets: [
        .target(
            name: "PTTalk",
            dependencies: [
                .product(name: "PTCore", package: "PTCore"),
                .product(name: "PTLanes", package: "PTLanes"),
                .product(name: "PTLocal", package: "PTLocal"),
            ]
        ),
        .testTarget(
            name: "PTTalkTests",
            dependencies: ["PTTalk", .product(name: "PTLanes", package: "PTLanes"), .product(name: "PTLocal", package: "PTLocal")],
            path: "Tests/PTTalkTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
